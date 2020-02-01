Domain Manager
==============

This tool helps manage domain registrations using a configuration file.

Operation
---------

1. The registrar-agnostic user configuration file is read from `conf/domains.yaml`.
2. For each registrar:
   1. The current settings are queried using the registrar's API.
   2. The user configuration is converted into the registrar's internal (API) data model.
   3. The results from steps 2.1 and 2.2 are compared, 
      and differences are translated into a sequence of actions 
      which would bring the current settings up to date with the user configuration.
3. The list of actions is presented to the user for review.
4. Upon confirmation, the actions are executed.

Following one successful execution, a second execution (with no changes to the configuration file) should be a no-op.

Example configuration
---------------------

```yaml
defs:

  - &my_nameservers
    - hostname: a.ns.example.com
      ips:
      - 1.2.3.4
      - 12:34::56:78
    - hostname: f.ns.example.com
      ips:
      - 5.6.7.8
      - 90:ab::cd:ef

domains:
  namesilo:

    example.com:
      locked: true
      autoRenew: true
      privacyEnabled: true
      nameservers: *my_nameservers

    example.org:
      locked: false
      autoRenew: false
      privacyEnabled: false
      nameservers: *my_nameservers
```

Usage
-----

1. Clone the repository.
2. Place configuration into `conf/domains.yaml`.
3. Place registrar configuration into `conf/<registrar>.ini`.
4. Install [a D compiler](https://dlang.org/download.html).
5. Type `dub` to run the tool.
   You will be given a chance to review all changes before any change is performed.

Supported registrars
--------------------

- [namesilo.com](https://www.namesilo.com/)

Unsupported registrars
----------------------

- dreamhost.com 

  Registration API is read-only.

- namecheap.com 

  No way to set glue records via API.
