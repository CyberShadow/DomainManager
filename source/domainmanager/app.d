module domainmanager.app;

import std.stdio;

import ae.sys.net.curl;

import domainmanager.common;
import domainmanager.config;
import domainmanager.registrars;

State getLiveState()
{
	State state;
	foreach (name, registrar; registrars)
		state[name] = registrar.getState();
	return state;
}

void main()
{
	auto userConfig = loadConfig();
	auto liveConfig = getLiveState();

	writeln(userConfig);
	writeln(liveConfig);
}
