module domainmanager.registrars.namesilo;

import std.algorithm.iteration;
import std.algorithm.sorting;
import std.array;
import std.conv : to;
import std.exception;
import std.string;
import std.typecons;
import std.utf;

import ae.net.ietf.url;
import ae.sys.log;
import ae.sys.net;
import ae.utils.sini;
import ae.utils.xml.lite;

import domainmanager.common;
import domainmanager.rdiff;

final class NameSilo : Registrar
{
	static struct Config
	{
		string apiKey;
	}
	Config config;

	Logger log;

	this()
	{
		config = loadIni!Config("conf/namesilo.ini");
		log = createLogger("NameSilo");
	}

	// Data model

	private static struct InternalState
	{
		struct Domain
		{
			struct Info
			{
				bool locked;
				bool private_;
				bool autoRenew;
				string[] nameservers;
			}
			Info info;

			struct RegisteredNameserver
			{
				string[] ips;
			}
			RegisteredNameserver[string] registeredNameservers;
		}
		Domain[string] domains;
	}

	private InternalState convertState(RegistrarState r)
	{
		InternalState i;
		foreach (name, rdom; r)
		{
			InternalState.Domain idom = {
				info : {
					locked : rdom.locked,
					private_ : rdom.privacyEnabled,
					autoRenew : rdom.autoRenew,
					nameservers : (
						rdom.nameservers
						.map!(ns => ns.hostname)
						.array
					),
				},
				registeredNameservers : (
					rdom.nameservers
					.filter!(ns => ns.ips.length > 0)
					.map!(ns => tuple(ns.hostname, InternalState.Domain.RegisteredNameserver(ns.ips)))
					.assocArray
				),
			};
			i.domains[name] = idom;
		}
		return i;
	}

	// API protocol

	private XmlNode apiCall(string operation, string[string] parameters)
	{
		log(format("%s %s", operation, parameters));
		parameters = parameters.dup;
		parameters["version"] = "1";
		parameters["type"] = "xml";
		parameters["key"] = config.apiKey;
		auto url = "https://www.namesilo.com/api/" ~ operation ~ "?" ~ encodeUrlParameters(parameters);
		auto response = cast(string)getFile(url);
		validate(response);
		auto doc = xmlParse(response);
		auto root = doc["namesilo"];
		auto req = root["request"];
		enforce(req["operation"].text == operation, "Operation mismatch");
		auto reply = root["reply"];
		enforce(reply["code"].text == "300", "Unexpected reply code: " ~ reply["code"].text);
		enforce(reply["detail"].text == "success", "Unexpected reply detail: " ~ reply["detail"].text);
		return reply;
	}

	private static bool parseBoolean(string s)
	{
		switch (s.strip)
		{
			case "Yes": return true;
			case "No" : return false;
			default: throw new Exception("Unknown boolean value: " ~ s);
		}
	}

	// API operations

	private string[] listDomains()
	{
		return apiCall("listDomains", null)
			["domains"]
			.findChildren("domain")
			.map!(node => node.text.strip)
			.array;
	}

	private InternalState.Domain.Info getDomainInfo(string domain)
	{
		auto reply = apiCall("getDomainInfo", ["domain" : domain]);
		InternalState.Domain.Info info = {
			locked      : parseBoolean(reply["locked"    ].text),
			private_    : parseBoolean(reply["private"   ].text),
			autoRenew   : parseBoolean(reply["auto_renew"].text),
			nameservers : reply["nameservers"]
				.findChildren("nameserver")
				.schwartzSort!(node => node.attributes["position"].to!int)
				.map!(node => node.text)
				.array
		};
		return info;
	}

	private InternalState.Domain.RegisteredNameserver[string] listRegisteredNameServers(string domain)
	{
		return apiCall("listRegisteredNameServers", ["domain" : domain])
			.findChildren("hosts")
			.map!(node => tuple(
					node["host"].text,
					InternalState.Domain.RegisteredNameserver(node.findChildren("ip").map!(node => node.text).array)
				)
			)
			.assocArray;
	}

	// State query

	private InternalState getState()
	{
		InternalState state;
		foreach (domain; listDomains)
			state.domains[domain] = InternalState.Domain(
				getDomainInfo(domain),
				listRegisteredNameServers(domain),
			);
		return state;
	}

	// Common interface
	
	override Action[] putState(RegistrarState state)
	{
		InternalState source = getState();
		InternalState target = convertState(state);

		Action[] actions;

		struct Handler
		{
			NameSilo self;

			void changed_domains_value_info_locked(bool /*oldValue*/, bool newValue, string domain)
			{
				if (newValue)
					actions ~= Action("Lock domain %s"  .format(domain), { self.apiCall("domainLock"  , ["domain" : domain]); });
				else
					actions ~= Action("Unlock domain %s".format(domain), { self.apiCall("domainUnlock", ["domain" : domain]); });
			}

			void changed_domains_value_info_private_(bool /*oldValue*/, bool newValue, string domain)
			{
				if (newValue)
					actions ~= Action("Enable privacy for %s" .format(domain), { self.apiCall("addPrivacy"   , ["domain" : domain]); });
				else
					actions ~= Action("Disable privacy for %s".format(domain), { self.apiCall("removePrivacy", ["domain" : domain]); });
			}

			void changed_domains_value_info_autoRenew(bool /*oldValue*/, bool newValue, string domain)
			{
				if (newValue)
					actions ~= Action("Enable auto-renew for %s" .format(domain), { self.apiCall("addAutoRenewal"   , ["domain" : domain]); });
				else
					actions ~= Action("Disable auto-renew for %s".format(domain), { self.apiCall("removeAutoRenewal", ["domain" : domain]); });
			}

			void changed_domains_value_info_nameservers(in string[] /*oldValue*/, in string[] newValue, string domain)
			{
				enforce(newValue.length < 13, "Too many nameservers!");
				auto parameters = ["domain" : domain];
				foreach (i, nameserver; newValue)
					parameters["ns%d".format(1 + i)] = nameserver;
				actions ~= Action("Change nameservers for %s to %s".format(domain, newValue),
					{ self.apiCall("changeNameServers", parameters); });
			}

			alias NS = InternalState.Domain.RegisteredNameserver;

			void added_domains_value_registeredNameservers_value(in ref NS newValue, string domain, string hostname)
			{
				enforce(newValue.ips.length < 13, "Too many IPs!");
				auto parameters = ["domain" : domain, "new_host" : hostname];
				foreach (i, ip; newValue.ips)
					parameters["ip%d".format(1 + i)] = ip;
				actions ~= Action("Add registered nameserver %s for %s".format(hostname, domain),
					{ self.apiCall("addRegisteredNameServer", parameters); });
			}

			void changed_domains_value_registeredNameservers_value(in ref NS oldValue, in ref NS newValue, string domain, string hostname)
			{
				enforce(newValue.ips.length < 13, "Too many IPs!");
				auto parameters = ["domain" : domain, "current_host" : hostname, "new_host" : hostname];
				foreach (i, ip; newValue.ips)
					parameters["ip%d".format(1 + i)] = ip;
				actions ~= Action("Update IPs of registered nameserver %s for %s".format(hostname, domain),
					{ self.apiCall("modifyRegisteredNameServer", parameters); });
			}

			void removed_domains_value_registeredNameservers_value(in ref NS oldValue, string domain, string hostname)
			{
				actions ~= Action("Remove registered nameserver %s for %s".format(hostname, domain),
					{ self.apiCall("deleteRegisteredNameServer", ["domain" : domain, "current_host" : hostname]); });
			}

			void added_domains_value(in ref InternalState.Domain newValue, string domain)
			{
				// Domain registration not implemented ;)
				throw new Exception("Unregistered domain: %s".format(domain));
			}

			void removed_domains_value(in ref InternalState.Domain newValue, string domain)
			{
				throw new Exception("Unconfigured domain: %s".format(domain));
			}
		}
		auto handler = new Handler(this);

		rdiff(source, target, handler);
		return actions;
	}
}

static this()
{
	registrars["namesilo"] = new NameSilo;
}
