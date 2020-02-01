module domainmanager.registrars.namesilo;

import std.algorithm.iteration;
import std.algorithm.sorting;
import std.array;
import std.conv : to;
import std.exception;
import std.string;
import std.utf;

import ae.net.ietf.url;
import ae.sys.log;
import ae.sys.net;
import ae.utils.sini;
import ae.utils.xml.lite;

import domainmanager.common;

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

	static bool parseBoolean(string s)
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

	Domain getDomainInfo(string domain)
	{
		auto reply = apiCall("getDomainInfo", ["domain" : domain]);
		Domain info;
		info.locked         = parseBoolean(reply["locked"    ].text);
		info.privacyEnabled = parseBoolean(reply["private"   ].text);
		info.autoRenew      = parseBoolean(reply["auto_renew"].text);
		info.nameservers = reply["nameservers"]
			.findChildren("nameserver")
			.schwartzSort!(node => node.attributes["position"].to!int)
			.map!(node => node.text)
			.array;
		return info;
	}

	// Common interface
	
	override RegistrarState getState()
	{
		RegistrarState state;
		foreach (domain; listDomains)
			state.domains[domain] = getDomainInfo(domain);
		return state;
	}
}

static this()
{
	registrars["namesilo"] = new NameSilo;
}
