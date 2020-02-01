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
