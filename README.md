---
<sup>**IMPORTANT:-** This has been developed as a starting point or foundation and is not necessarily considered "complete". It is being made available to allow learning, development, and knowledge-sharing amongst communities.<br>
</sup>

---

## What is PSADT-WingetFW

PSADT-WingetFW is framework for using Winget with PSADT with havning to create a script for each application
## EXAMPLES
### EXAMPLE 1
```
Deploy-Application.exe -DeploymentType "Install" -WingetID "Postman.Postman"
```

![alt text](https://github.com/kriskristensen3/PSADT-WingetFW/blob/main/Images/exampleInstallCommand01.png?raw=true)
### EXAMPLE 2
```
ServiceUI.exe -process:explorer.exe Deploy-Application.exe -DeploymentType "Install" -WingetID "Neovim.Neovim" -WingetScope '--Scope machine'
```
![alt text](https://github.com/kriskristensen3/PSADT-WingetFW/blob/main/Images/exampleInstallCommand02.png?raw=true)

## PARAMETERS
### -DeploymentType

### --WingetCM

### -Mode

### --Scope

### --WingetCM
