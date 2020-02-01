module domainmanager.config;

import dyaml;
import yamlserialized;

import ae.utils.aa;

import domainmanager.common;

struct YamlConfig
{
	State domains;
}

State loadConfig()
{
	YamlConfig config;
	Loader.fromFile("conf/domains.yaml").load().deserializeInto(config);
	return config.domains;
}
