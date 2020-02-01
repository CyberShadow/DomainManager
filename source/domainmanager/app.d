module domainmanager.app;

import std.exception;
import std.stdio;
import std.string;

import ae.sys.net.curl;
import ae.utils.funopt;
import ae.utils.main;

import domainmanager.common;
import domainmanager.config;
import domainmanager.registrars;

void domainManager()
{
	stderr.writeln("Loading configuration");
	auto userConfig = loadConfig();

	stderr.writeln("Calculating changes");
	Action[] actions;
	foreach (name, registrar; registrars)
		actions ~= registrar.putState(userConfig.get(name, RegistrarState.init));

	if (!actions.length)
	{
		writeln("Nothing to do!");
		return;
	}

	writeln("TODO:");
	foreach (action; actions)
		writeln(" - ", action.description);

	write("Commit? (Type uppercase \"yes\"): "); stdout.flush();
	if (readln().strip != "YES")
	{
		writeln("User abort");
		return;
	}

	foreach (action; actions)
	{
		stderr.writeln("Performing action: " ~ action.description);
		action.execute();
	}
}

mixin main!(funopt!domainManager);
