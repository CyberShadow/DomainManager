/*  Copyright (C) 2020  Vladimir Panteleev <vladimir@thecybershadow.net>
 *
 *  This program is free software: you can redistribute it and/or modify
 *  it under the terms of the GNU Affero General Public License as
 *  published by the Free Software Foundation, either version 3 of the
 *  License, or (at your option) any later version.
 *
 *  This program is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *  GNU Affero General Public License for more details.
 *
 *  You should have received a copy of the GNU Affero General Public License
 *  along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */

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
