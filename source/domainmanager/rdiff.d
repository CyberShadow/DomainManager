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

module domainmanager.rdiff;

import std.traits;

void rdiff(T, H)(in ref T a, in ref T b, ref H handler)
{
	void scan(string pathName, T, Path...)(in ref T a, in ref T b, auto ref Path path)
	{
		if (a == b)
			return;

		static if (__traits(hasMember, H, "changed" ~ pathName))
			mixin(`handler.changed` ~ pathName ~ `(a, b, path);`);
		else
		{
			static if (isAssociativeArray!T)
			{
				enum nextPathName = pathName ~ "_value";
				foreach (key, ref aVal; a)
				{
					auto pbVal = key in b;
					if (pbVal)
						scan!nextPathName(aVal, *pbVal, path, key);
					else
						mixin(`handler.removed` ~ nextPathName ~ `(aVal, path, key);`);
				}
				foreach (key, ref bVal; b)
				{
					if (key !in a)
						mixin(`handler.added` ~ nextPathName ~ `(bVal, path, key);`);
				}
			}
			else
			static if (is(T == struct))
			{
				foreach (i, field; T.init.tupleof)
				{
					enum name = __traits(identifier, T.tupleof[i]);
					enum nextPathName = pathName ~ "_" ~ name;
					scan!nextPathName(mixin(`a.` ~ name), mixin(`b.` ~ name), path);
				}
			}
			else
				static assert(false, "Don't know how to diff " ~ T.stringof ~ " at " ~ pathName);
		}
	}

	scan!null(a, b);
}
