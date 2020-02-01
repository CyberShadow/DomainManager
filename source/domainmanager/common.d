module domainmanager.common;

struct Nameserver
{
	string hostname;
	string[] ips;
}

struct Domain
{
	// name is key
	bool locked;
	bool privacyEnabled;
	bool autoRenew;
	Nameserver[] nameservers;
}

alias RegistrarState = Domain[string];

alias State = RegistrarState[string /*registrar*/];

struct Action
{
	string description;
	void delegate() execute;
}

class Registrar
{
	abstract Action[] putState(RegistrarState);
}

Registrar[string] registrars;
