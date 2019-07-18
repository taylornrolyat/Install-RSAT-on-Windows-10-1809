# PowerShell script to install the Remote Server Administration Tools (RSAT) on Windows 10 1809+

Microsoft no longer provides a installer package for the Remote Server Administration Tools on Windows 10 Version 1809+. This script will install all of the tools without needing to use the GUI. It requires an active internet connection to install the tools.  

If you currently block online updates because your organization uses WSUS, it will temporarily change the registry keys to allow online updates and install the tools using DISM.exe. The registry keys will be reverted back after the installation is complete. 

For more information, consult https://www.microsoft.com/en-us/download/details.aspx?id=45520

## Example:
![Image](https://github.com/taylornrolyat/Install-RSAT-on-Windows-10-1809/blob/master/rsat%20installer%20example.jpg)
