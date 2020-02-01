module domainmanager.common;

struct Domain
{
	// name is key
	bool locked;
	bool privacyEnabled;
	bool autoRenew;
	string[] nameservers;
}

struct RegistrarState
{
	Domain[string] domains;
}

alias State = RegistrarState[string /*registrar*/];

class Registrar
{
	abstract RegistrarState getState();
}

Registrar[string] registrars;
