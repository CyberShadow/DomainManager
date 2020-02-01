module domainmanager.config;

import dyaml;
import yamlserialized;

import ae.utils.aa;

import domainmanager.common;

struct YamlConfig
{
	struct Domain
	{
		string registrar;
		bool locked;
		bool privacyEnabled;
		bool autoRenew;
		string[] nameservers;
	}
	Domain[string] domains;
}

State loadConfig()
{
	YamlConfig config;
	Loader.fromFile("conf/domains.yaml").load().deserializeInto(config);

	State state;
	foreach (name, info; config.domains)
	{
		Domain domain = {
			locked : info.locked,
			privacyEnabled : info.privacyEnabled,
			autoRenew : info.autoRenew,
			nameservers : info.nameservers,
		};
		state.require(info.registrar).domains.addNew(name, domain);
	}
	return state;
}
