# This batch file creates a person account scratch org sfdx-project-person-accounts.json configuration file
sfdx force:org:create -f config/project-scratch-person-accounts.json -a personaccountorg
sfdx force:source:push -u personaccountorg
