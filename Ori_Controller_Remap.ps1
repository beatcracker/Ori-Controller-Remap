# Dummy param block to allow Verbose switch
[CmdletBinding()]
Param()

#region Helper functions

<#
.Synopsis
	Gets the content of an INI file

.Description
	Gets the content of an INI file and returns it as a hashtable

.Notes
	Author        : Oliver Lipkau <oliver@lipkau.net>
	Blog        : http://oliver.lipkau.net/blog/
	Source        : https://github.com/lipkau/PsIni
					http://gallery.technet.microsoft.com/scriptcenter/ea40c1ef-c856-434b-b8fb-ebd7a76e8d91
	Version        : 1.0 - 2010/03/12 - Initial release
					1.1 - 2014/12/11 - Typo (Thx SLDR)
										Typo (Thx Dave Stiff)

	#Requires -Version 2.0

.Inputs
	System.String

.Outputs
	System.Collections.Hashtable

.Parameter FilePath
	Specifies the path to the input file.

.Example
	$FileContent = Get-IniContent "C:\myinifile.ini"
	-----------
	Description
	Saves the content of the c:\myinifile.ini in a hashtable called $FileContent

.Example
	$inifilepath | $FileContent = Get-IniContent
	-----------
	Description
	Gets the content of the ini file passed through the pipe into a hashtable called $FileContent

.Example
	C:\PS>$FileContent = Get-IniContent "c:\settings.ini"
	C:\PS>$FileContent["Section"]["Key"]
	-----------
	Description
	Returns the key "Key" of the section "Section" from the C:\settings.ini file

.Link
	Out-IniFile
#>
Function Get-IniContent
{
	[CmdletBinding()]
	Param
	(
		[ValidateNotNullOrEmpty()]
		[ValidateScript({
			(Test-Path $_) -and ((Get-Item $_).Extension -eq '.ini')
		})]
		[Parameter(ValueFromPipeline = $true, Mandatory = $true)]
		[string]$FilePath
	)

	Process
	{
		Write-Verbose "Reading ini file: $Filepath"

		$ini = @{}
		switch -regex -file $FilePath
		{
			'^\[(.+)\]$' # Section
			{
				$section = $matches[1]
				$ini[$section] = @{}
				$CommentCount = 0
			}
			'^(;.*)$' # Comment
			{
				if (!($section))
				{
					$section = 'No-Section'
					$ini[$section] = @{}
				}
				$value = $matches[1]
				$CommentCount = $CommentCount + 1
				$name = 'Comment' + $CommentCount
				$ini[$section][$name] = $value
			}
			'(.+?)\s*=\s*(.*)' # Key
			{
				if (!($section))
				{
					$section = 'No-Section'
					$ini[$section] = @{}
				}
				$name,$value = $matches[1..2]
				$ini[$section][$name] = $value
			}
		}

		$ini
	}
}

<#
.Synopsis
	PowerShell pause implementation

.Link
	https://adamstech.wordpress.com/2011/05/12/how-to-properly-pause-a-powershell-script/
#>
function Pause {

    Param
    (
        [string]$Message = 'Press any key to continue...',

        [Parameter(ValueFromRemainingArguments = $true)]
        $PassMe
    )

	If ($psISE) {
		# The "ReadKey" functionality is not supported in Windows PowerShell ISE.

		#$Shell = New-Object -ComObject 'WScript.Shell'
		#$Button = $Shell.Popup('Click OK to continue.', 0, 'Script Paused', 0)

		return
	}

	Show-Text -Text $Message -NoNewline $PassMe

	$Ignore =
		16,  # Shift (left or right)
		17,  # Ctrl (left or right)
		18,  # Alt (left or right)
		20,  # Caps lock
		91,  # Windows key (left)
		92,  # Windows key (right)
		93,  # Menu key
		144, # Num lock
		145, # Scroll lock
		166, # Back
		167, # Forward
		168, # Refresh
		169, # Stop
		170, # Search
		171, # Favorites
		172, # Start/Home
		173, # Mute
		174, # Volume Down
		175, # Volume Up
		176, # Next Track
		177, # Previous Track
		178, # Stop Media
		179, # Play
		180, # Mail
		181, # Select Media
		182, # Application 1
		183  # Application 2

	While ($KeyInfo.VirtualKeyCode -Eq $Null -Or $Ignore -Contains $KeyInfo.VirtualKeyCode) {
		$KeyInfo = $Host.UI.RawUI.ReadKey('NoEcho, IncludeKeyDown')
	}

	Write-Host
}

<#
.Synopsis
	Get path to game's assembly directory. Searches registry + paths specified in Path parameter.
#>
function Get-GameAssemblyDirectory
{
	[CmdletBinding()]
	Param
	(
		[Parameter(ValueFromPipelineByPropertyName = $true)]
		[ValidateNotNullOrEmpty()]
		[string[]]$Path,

		[Parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true)]
		[ValidateNotNullOrEmpty()]
		[string]$GameAssembly
	)

	Begin
	{
		$AssemblySubdir = 'ori_Data\Managed'
		$RegistryKeys = @{
			'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\Steam App 261570' = 'InstallLocation'
			'HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\Steam App 261570' = 'InstallLocation'
		}
	}

	Process
	{
		# Get Ori installation directory from registry
		[string[]]$PathsFromRegistry = $RegistryKeys.GetEnumerator() |
			ForEach-Object {
				$InstallDir = (Get-ItemProperty -Path $_.Key -ErrorAction SilentlyContinue).($_.Value)
				if($InstallDir)
				{
					Join-Path -Path $InstallDir -ChildPath $AssemblySubDir
				}
			}

		# Check all paths for game assembly file (Assembly-CSharp.dll)
		# and return first valid one
		$Path + $PathsFromRegistry | ForEach-Object {
			$PathToGameAssembly = Join-Path -Path $_ -ChildPath $GameAssembly
			if(Test-Path -Path $PathToGameAssembly -PathType Leaf)
			{
				$_
			}
		} | Select-Object -First 1
	}

}

<#
.Synopsis
    Show text on screen, optionally center it and specify color.
    Centering works only in PS console, not ISE.
#>
function Show-Text
{
    [CmdletBinding()]
    Param
    (
        [Parameter(ValueFromPipeline = $true)]
        [string]$Text,

        [Parameter(ValueFromPipelineByPropertyName = $true)]
        [ValidateScript({
            [Enum]::GetValues([ConsoleColor]) -contains $_
        })]
        [string]$ForegroundColor,

        [Parameter(ValueFromPipelineByPropertyName = $true)]
        [ValidateScript({
            [Enum]::GetValues([ConsoleColor]) -contains $_
        })]
        [string]$BackgroundColor,

        [Parameter(ValueFromPipelineByPropertyName = $true)]
        [switch]$Center,

        [Parameter(ValueFromPipelineByPropertyName = $true)]
        [switch]$NoNewline,

        [Parameter(ValueFromPipelineByPropertyName = $true)]
        [switch]$AsSeparator
    )

    Begin
    {
        # Get console width (PS console only)
        $ConsoleWidth = $host.UI.RawUI.WindowSize.Width
    }

    Process
    {
        # This will allow Write-Host to use default values for ForegroundColor\BackgroundColor
        $WriteHost = {
            '$_ | Write-Host'
            if($ForegroundColor){'-ForegroundColor $ForegroundColor'}
            if($BackgroundColor){'-BackgroundColor $BackgroundColor'}
            if($NoNewline){'-NoNewline'}
        }

        # Treat Text as Separator?
        if($AsSeparator)
        {
            # Create separator
            $ret = $Text * ($ConsoleWidth / $Text.Length)
        }
        else
        {
            # If Center switch specified and we're in PS console
            if($Center -and $ConsoleWidth)
            {
                # Pad text to center it
                $ret = $Text | ForEach-Object {
                        $_ -split [System.Environment]::NewLine | ForEach-Object {
                            $PadSize = [System.Math]::Floor($ConsoleWidth/2 - $_.Length/2)
                            $_.PadLeft($_.Length + $PadSize)
                        }
                    } 
            }
            else
            {
                # Do nothing to text
                $ret = $Text
            }
        }

        # Display text
        $ret  | ForEach-Object -Process ([scriptblock]::Create($WriteHost.InvokeReturnAsIs() -join ' '))
    }
}

<#
	.Synopsis
		Menu, where user selects patch mode
#>
function Show-PatchModeMenu
{
	Param
	(
		[Parameter(Mandatory = $true)]
		[hashtable]$Mode
	)

	# Create menu from hashtable
	$Keys = $Mode.GetEnumerator() | ForEach-Object {$_.Key} | Sort-Object
	$PropertyOrder = @('Number', 'Name', 'Description')

	$i = 0
	$Menu = $Keys | ForEach-Object {
		New-Object -TypeName psobject -Property (@{ Number = $i ; Name = $_ ; Description = $Mode[$_]}) |
			Select-Object -Property $PropertyOrder
		$i++
	}

	$Choice = -1
	Write-Host 'Available patch modes:' -ForegroundColor Yellow
	$Menu | Format-Table -AutoSize -Property * | Out-String | Write-Host -ForegroundColor Green

	while($Choice -lt 0 -or $Choice -gt $i)
	{
		Write-Host 'Select patch mode number: ' -ForegroundColor Yellow -NoNewline
		$Choice = [int](Read-Host)
	}

	Write-Host 'Active patch mode:' -ForegroundColor Yellow
	$Menu[$Choice] | Format-Table -AutoSize -Property * | Out-String | Write-Host -ForegroundColor Green
	$Menu[$Choice].Name
}

<#
	.Synopsis
		Menu, where user selects custom controller mapping
#>
function Show-ControllerMappingMenu
{
	Param
	(
		[Parameter(Mandatory = $true)]
		[hashtable]$Custom
	)

	# Create menu from hashtable with button mappings
	$Keys = $Custom.GetEnumerator() | ForEach-Object {$_.Key} | Sort-Object
	$PropertyOrder = @(
		'Number', 'Name',
		'A', 'B', 'X', 'Y',
		'LTrigger', 'RTrigger',
		'LShoulder', 'RShoulder',
		'LStick', 'RStick',
		'Select', 'Start'
	)

	$i = 0
	$Menu = $Keys | ForEach-Object {
		New-Object -TypeName psobject -Property (@{Name = $_ ; Number = $i} + $Custom[$_]) |
			Select-Object -Property $PropertyOrder
		$i++
	}

	$Choice = -1
	Write-Host 'Available controller mappings:' -ForegroundColor Yellow
	$Menu | Format-Table -AutoSize -Property * | Out-String | Write-Host -ForegroundColor Green

	while($Choice -lt 0 -or $Choice -gt $i)
	{
		Write-Host 'Select configuration number: ' -ForegroundColor Yellow -NoNewline
		$Choice = [int](Read-Host)
	}

	Write-Host 'Active configuration:' -ForegroundColor Yellow
	$Menu[$Choice] | Format-Table -AutoSize -Property * | Out-String | Write-Host -ForegroundColor Green
	$Custom[$Menu[$Choice].Name]
}

<#
.Synopsis
	Generate assembly from C# source code

.Parameter String
	String containig C# source code

.Parameter File
	File containig C# source code

.Parameter OutputAssembly
	Path to the new assembly file

.Parameter ReferencedAssemblies
	Array of paths to the assemblies, referenced by source code

.Parameter CompilerVersion
	C# compiler version to use. Valid values: 'v2.0', 'v3.0', 'v3.5', 'v4.0'

.Parameter CompilerOptions
	Array of the the C# compiler options: https://msdn.microsoft.com/en-us/library/6ds95cz0.aspx

.Parameter IncludeDebugInformation
	True if debug information should be generated; otherwise, false.
	https://msdn.microsoft.com/en-us/library/system.codedom.compiler.compilerparameters.includedebuginformation.aspx
#>
function New-AssemblyFromSource
{
	[CmdletBinding(DefaultParameterSetName = 'String')]
	Param
	(
		[Parameter(Mandatory = $true, ValueFromPipeline = $true, ParameterSetName = 'String')]
		[ValidateNotNullOrEmpty()]
		[string]$String,

		[Parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true, ParameterSetName = 'File')]
		[ValidateScript({
			if(!(Test-Path -Path $_ -PathType Leaf))
			{
				throw [System.IO.FileNotFoundException] "File not found: $_"
			}
			$true
		})]
		[ValidateNotNullOrEmpty()]
		[string]$File,

		[Parameter(ValueFromPipelineByPropertyName = $true)]
		[ValidateNotNullOrEmpty()]
		[ValidateScript({
			if(!(Test-Path -Path (Split-Path -Path $_) -PathType Container))
			{
				throw [System.IO.FileNotFoundException] "Folder not found: $_"
			}
			$true
		})]
		[string]$OutputAssembly,

		[Parameter(ValueFromPipelineByPropertyName = $true)]
		[string[]]$ReferencedAssemblies,

		[Parameter(ValueFromPipelineByPropertyName = $true)]
		[ValidateSet('v2.0', 'v3.0', 'v3.5', 'v4.0')]
		[string]$CompilerVersion,

		[Parameter(ValueFromPipelineByPropertyName = $true)]
		[ValidateNotNullOrEmpty()]
		[string[]]$CompilerOptions,

		[Parameter(ValueFromPipelineByPropertyName = $true)]
		[switch]$IncludeDebugInformation
	)

	Process
	{
		# Set compiler version, if specified
		if($CompilerVersion)
		{
			$CompilerVersionDict = New-Object -TypeName 'System.Collections.Generic.Dictionary[String,String]'
			$CompilerVersionDict.Add('CompilerVersion', $CompilerVersion)
			$Provider = New-Object -TypeName Microsoft.CSharp.CSharpCodeProvider -ArgumentList $CompilerVersionDict
		}
		else
		{
			$Provider = New-Object -TypeName Microsoft.CSharp.CSharpCodeProvider
		}

		# Create new compiler parameters' object
		$CompilerParameters = New-Object -TypeName System.CodeDom.Compiler.CompilerParameters

		# Set compiler parameters
		$CompilerParameters.GenerateInMemory  = $false
		$CompilerParameters.IncludeDebugInformation = $IncludeDebugInformation
		if(!$OutputAssembly)
		{
			$OutputAssembly = [System.IO.Path]::GetTempFileName()
		}
		$CompilerParameters.OutputAssembly = $OutputAssembly

		# Set compiler options
		if($CompilerOptions)
		{
			$CompilerParameters.CompilerOptions = $CompilerOptions -join ' '
		}

		# Add referenced assemblies
		if($ReferencedAssemblies)
		{
			$CompilerParameters.ReferencedAssemblies.AddRange($ReferencedAssemblies)
		}

		if($String)
		{
			# Generate assembly from string
			$CompilerResults = $Provider.CompileAssemblyFromSource($CompilerParameters, $String)
		}
		else
		{
			# Generate assembly from file
			$CompilerResults = $Provider.CompileAssemblyFromSource($CompilerParameters, ([System.IO.File]::ReadAllText($File)))
		}

		if($CompilerResults.Errors.Count -gt 0)
		{
			# Return compiler errors if any
			throw $CompilerResults.Errors
		}
		else
		{
			# Otherwise, return path to generated assembly
			$CompilerResults.PathToAssembly
		}
	}
}

<#
.Synopsis
	Get member of a class

.Parameter AssemblyDefinition
	[Mono.Cecil.Reflexil.AssemblyDefinition] to get class and member from

.Parameter Class
	String. Class name.

.Parameter Member
	String. Member name

.Parameter MemberType
	String. This is the name of the method, used to get a member of the class.

	For a method: Methods
	For a field: NestedTypes
#>
function Get-ClassMember
{
	[CmdletBinding()]
	Param
	(
		[Parameter(Mandatory = $true, ValueFromPipeline = $true)]
		[Mono.Cecil.Reflexil.AssemblyDefinition]$AssemblyDefinition,

		[Parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true)]
		[string]$Class,

		[Parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true)]
		[string]$Member,

		[Parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true)]
		[ValidateSet('Methods', 'NestedTypes')]
		[string]$MemberType
	)

	Process
	{
		($AssemblyDefinition.MainModule.Types |Where-Object {$_.Name -eq $Class})."$MemberType" |
			Where-Object {$_.Name -eq $Member}
	}
}

<#
.Synopsis
	Get source code for the GetButton method with remapped buttons.

.Parameter Default
	Hashtable. Default button mapping.

.Parameter Custom
	Hashtable. Custom button mapping.

.Parameter Base
	Int. This number will be subtracted from custom button's number.
	Allows users to store button numbers in ini file that start from 1 (internal mappings start from 0).
#>
function New-RawInputGetButtonMethodSource
{
	[CmdletBinding()]
	Param
	(
		[Parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true, ParameterSetName = 'Remap')]
		[hashtable]$Default,

		[Parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true, ParameterSetName = 'Remap')]
		[hashtable]$Custom,

		[Parameter(ValueFromPipelineByPropertyName = $true, ParameterSetName = 'Remap')]
		[int]$Base = 1,

		[Parameter(Mandatory = $true, ParameterSetName = 'Remap')]
        [switch]$Remap,

		[Parameter(Mandatory = $true, ParameterSetName = 'Disable')]
        [switch]$Disable
	)

	Begin
	{
		# Source code for the GetButton method with remapping
		$GetButtonMethodSourceRemap = {@"
			public static bool GetButton(string buttonName)
			{
				// string[] strArray = new string[] { "1", "2", "0", "3", "4", "5", "8", "9", "10", "11", "6", "7" };
				string[] strArray = new string[] {$($NewButtonMappingArray -join ',')};
				Match match = Regex.Match(buttonName, @"^(Joystick\dButton)([0-9]|1[0-1])$", RegexOptions.Singleline);
				if (match.Success)
				{
					return Input.GetButton(match.Groups[1].Value + strArray[int.Parse(match.Groups[2].Value)]);
				}
				return Input.GetButton(buttonName);
			}
"@}

		# Source code for the GetButton method that disables RawInput
        $GetButtonMethodSourceDisable = @'
            public static bool GetButton(string buttonName)
            {
                return false;
            }
'@

	}

	Process
	{
        if($Remap)
        {
		    # Create array of button mappings
		    $NewButtonMappingArray = New-Object -TypeName string[] -ArgumentList $Default.Count
		    for($i = 0; $i -lt $Default.Count; $i++)
		    {
			    $NewButtonMappingArray[$i] = '"' + ($Custom[$Default[$i]] - $Base) + '"'
		    }

		    # Return new GetButton method with custom button mapping array
		    $GetButtonMethodSourceRemap.InvokeReturnAsIs()
        }
        elseif($Disable)
        {
            $GetButtonMethodSourceDisable
        }
	}
}

function New-GameAssemblySource
{
    [CmdletBinding()]
    Param
    (
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [string]$RawInputGetButtonMethodSource
    )
    Begin
    {
        $XInputGetButtonMethodSource = {@"
            #region " Imports "
            using J2i.Net.XInputWrapper;
            using System;
            using System.Collections.Generic;
            using System.Text;
            using System.Text.RegularExpressions;
            using UnityEngine;
            #endregion

            #region " Referenced assemblies "
            // - UnityEngine v0.0.0.0
            // - mscorlib v2.0.5.0
            // - System.Core v2.0.5.0
            // - System v2.0.5.0
            // - SteamworksManaged v1.0.0.0
            // - J2i.Net.XInputWrapper v1.0.0.0
            // - Assembly-CSharp-firstpass v0.0.0.0
            // - Assembly-CSharp v0.0.0.0
            #endregion

            public class MoonInput
            {
                public static float GetAxis(string axisName)
                {
                    return default(float);
                }

                $RawInputGetButtonMethodSource
            }

            namespace SmartInput
            {
                public enum Axis
                {
                    LeftStickX,
                    LeftStickY,
                    RightStickX,
                    RightStickY,
                    DpadX,
                    DpadY
                }

                public enum Button
                {
                    ButtonA,
                    ButtonX,
                    ButtonY,
                    ButtonB,
                    LeftTrigger,
                    RightTrigger,
                    LeftShoulder,
                    RightShoulder,
                    LeftStick,
                    RightStick,
                    Select,
                    Start
                }

                class XboxControllerInput
                {
                    // Limited support!
                    // You can only reference methods or fields defined in the class (not in ancestors classes)
                    // Fields and methods stubs are needed for compilation purposes only.
                    // Reflexil will automaticaly map current type, fields or methods to original references.
                    public static bool GetButton(Button button, int userIndex = -1)
                    {
                        int axisUserIndex = GetAxisUserIndex();
                        if (userIndex != -1)
                        {
                            axisUserIndex = UserIndexToAxisUserIndex(userIndex);
                        }
                        int index = AxisIndexToButtonUserIndex(axisUserIndex);
                        XboxController controller = XboxController.RetrieveController((userIndex != -1) ? userIndex : 0);
                        switch (button)
                        {
                            case Button.ButtonA:
                                return (controller.IsAPressed || MoonInput.GetButton(m_joystickButton0Map[index]));

                            case Button.ButtonX:
                                return (controller.IsXPressed || MoonInput.GetButton(m_joystickButton2Map[index]));

                            case Button.ButtonY:
                                return (controller.IsYPressed || MoonInput.GetButton(m_joystickButton3Map[index]));

                            case Button.ButtonB:
                                return (controller.IsBPressed || MoonInput.GetButton(m_joystickButton1Map[index]));

                            case Button.LeftTrigger:
                                {
                                    bool flag = controller.LeftTrigger > 20;
                                    bool flag2 = MoonInput.GetAxis(m_joystickAxis9Map[axisUserIndex]) > 0.5f;
                                    bool flag3 = MoonInput.GetAxis(m_joystickAxis3Map[axisUserIndex]) > 0.5f;
                                    return ((flag || flag2) || flag3);
                                }
                            case Button.RightTrigger:
                                {
                                    bool flag4 = controller.RightTrigger > 20;
                                    bool flag5 = MoonInput.GetAxis(m_joystickAxis10Map[axisUserIndex]) > 0.5f;
                                    bool flag6 = MoonInput.GetAxis(m_joystickAxis3Map[axisUserIndex]) < -0.5f;
                                    return ((flag4 || flag5) || flag6);
                                }
                            case Button.LeftShoulder:
                                return (controller.IsLeftShoulderPressed || MoonInput.GetButton(m_joystickButton4Map[index]));

                            case Button.RightShoulder:
                                return (controller.IsRightShoulderPressed || MoonInput.GetButton(m_joystickButton5Map[index]));

                            case Button.LeftStick:
                                return (controller.IsLeftStickPressed || MoonInput.GetButton(m_joystickButton8Map[index]));

                            case Button.RightStick:
                                return (controller.IsRightStickPressed || MoonInput.GetButton(m_joystickButton9Map[index]));

                            case Button.Select:
                                return (controller.IsBackPressed || MoonInput.GetButton(m_joystickButton6Map[index]));

                            case Button.Start:
                                return (controller.IsStartPressed || MoonInput.GetButton(m_joystickButton7Map[index]));
                        }
                        return false;
                    }

                    #region " Methods stubs "
                    // Do not add or update any method. If compilation fails because of a method declaration, comment it
                    //static XboxControllerInput()
                    //{
                    //}

                    //static float ToAxisFloat(int axis)
                    //{
                    //    return default(float);
                    //}

                    //static float GetAxis(Axis axis)
                    //{
                    //    return default(float);
                    //}

                    static int UserIndexToAxisUserIndex(int userIndex)
                    {
                        return default(int);
                    }

                    static int GetAxisUserIndex()
                    {
                        return default(int);
                    }

                    static int AxisIndexToButtonUserIndex(int userIndex)
                    {
                        return default(int);
                    }

                    //static string GetJoystickXAxisYString(int x, int y)
                    //{
                    //    return default(string);
                    //}

                    #endregion

                    #region " Fields stubs "
                    // Do not add or update any field. If compilation fails because of a field declaration, comment it
                    static string m_joystick0Axis1;
                    static string m_joystick0Axis2;
                    static string m_joystick0Axis3;
                    static string m_joystick0Axis4;
                    static string m_joystick0Axis5;
                    static string m_joystick0Axis6;
                    static string m_joystick0Axis7;
                    static string m_joystick0Axis8;
                    static string m_joystick0Axis9;
                    static string m_joystick0Axis10;
                    static string m_joystick1Axis1;
                    static string m_joystick1Axis2;
                    static string m_joystick1Axis3;
                    static string m_joystick1Axis4;
                    static string m_joystick1Axis5;
                    static string m_joystick1Axis6;
                    static string m_joystick1Axis7;
                    static string m_joystick1Axis8;
                    static string m_joystick1Axis9;
                    static string m_joystick1Axis10;
                    static string m_joystick2Axis1;
                    static string m_joystick2Axis2;
                    static string m_joystick2Axis3;
                    static string m_joystick2Axis4;
                    static string m_joystick2Axis5;
                    static string m_joystick2Axis6;
                    static string m_joystick2Axis7;
                    static string m_joystick2Axis8;
                    static string m_joystick2Axis9;
                    static string m_joystick2Axis10;
                    static string m_joystick3Axis1;
                    static string m_joystick3Axis2;
                    static string m_joystick3Axis3;
                    static string m_joystick3Axis4;
                    static string m_joystick3Axis5;
                    static string m_joystick3Axis6;
                    static string m_joystick3Axis7;
                    static string m_joystick3Axis8;
                    static string m_joystick3Axis9;
                    static string m_joystick3Axis10;
                    static string m_joystick4Axis1;
                    static string m_joystick4Axis2;
                    static string m_joystick4Axis3;
                    static string m_joystick4Axis4;
                    static string m_joystick4Axis5;
                    static string m_joystick4Axis6;
                    static string m_joystick4Axis7;
                    static string m_joystick4Axis8;
                    static string m_joystick4Axis9;
                    static string m_joystick4Axis10;
                    static string m_joystick1Button0;
                    static string m_joystick1Button1;
                    static string m_joystick1Button2;
                    static string m_joystick1Button3;
                    static string m_joystick1Button4;
                    static string m_joystick1Button5;
                    static string m_joystick1Button6;
                    static string m_joystick1Button7;
                    static string m_joystick1Button8;
                    static string m_joystick1Button9;
                    static string m_joystick1Button10;
                    static string m_joystick2Button0;
                    static string m_joystick2Button1;
                    static string m_joystick2Button2;
                    static string m_joystick2Button3;
                    static string m_joystick2Button4;
                    static string m_joystick2Button5;
                    static string m_joystick2Button6;
                    static string m_joystick2Button7;
                    static string m_joystick2Button8;
                    static string m_joystick2Button9;
                    static string m_joystick2Button10;
                    static string m_joystick3Button0;
                    static string m_joystick3Button1;
                    static string m_joystick3Button2;
                    static string m_joystick3Button3;
                    static string m_joystick3Button4;
                    static string m_joystick3Button5;
                    static string m_joystick3Button6;
                    static string m_joystick3Button7;
                    static string m_joystick3Button8;
                    static string m_joystick3Button9;
                    static string m_joystick3Button10;
                    static string m_joystick4Button0;
                    static string m_joystick4Button1;
                    static string m_joystick4Button2;
                    static string m_joystick4Button3;
                    static string m_joystick4Button4;
                    static string m_joystick4Button5;
                    static string m_joystick4Button6;
                    static string m_joystick4Button7;
                    static string m_joystick4Button8;
                    static string m_joystick4Button9;
                    static string m_joystick4Button10;
                    static string[] m_joystickAxis1Map;
                    static string[] m_joystickAxis2Map;
                    static string[] m_joystickAxis3Map;
                    static string[] m_joystickAxis4Map;
                    static string[] m_joystickAxis5Map;
                    static string[] m_joystickAxis6Map;
                    static string[] m_joystickAxis7Map;
                    static string[] m_joystickAxis8Map;
                    static string[] m_joystickAxis9Map;
                    static string[] m_joystickAxis10Map;
                    static string[] m_joystickButton0Map;
                    static string[] m_joystickButton1Map;
                    static string[] m_joystickButton2Map;
                    static string[] m_joystickButton3Map;
                    static string[] m_joystickButton4Map;
                    static string[] m_joystickButton5Map;
                    static string[] m_joystickButton6Map;
                    static string[] m_joystickButton7Map;
                    static string[] m_joystickButton8Map;
                    static string[] m_joystickButton9Map;
                    #endregion

                }
            }
"@
}
    }
    
    Process
    {
        $XInputGetButtonMethodSource.InvokeReturnAsIs()
    }
}
#endregion


#region Configuration

# ASCII art for startup banner
$Banner = @{
    Ori = @'
     ___                                   ______                   ________)             
   /(,  )    ,           /)     /)        (, /    ) /) ,      /)   (, /                   
  /    / __      _ __  _(/   _/(/   _       /---(  //   __  _(/      /___, ____  _ _  _/_ 
 /    / / (_(_  (_(/ ((_(_   (_/ )_(/_   ) / ____)(/__(_/ ((_(_   ) /     (_) (_(//_)_(__ 
(___ /                                  (_/ (                    (_/                      
                                                                                          
'@

    Tool = @'
 __                                                                
/    _   _  |_  _  _  | |  _  _    _  _  _   _   _    |_  _   _  | 
\__ (_) | ) |_ |  (_) | | (- |    |  (- ||| (_| |_)   |_ (_) (_) | 
                                                |                  
'@
}

# Script's configuration and internal variables
$Cfg = @{
	Game = @{
		Assembly = 'Assembly-CSharp.dll'
		InstallDir = $null
	}
	Patch = @{
        CurrentMode = $null
        AvailableModes = @{
            Remap = 'Remap controller buttons'
            Disable = 'Disable RawInput (for use with x360ce)'
        }
        Set = @(
		    @{Class = 'MoonInput'
		    Member = 'GetButton'
		    MemberType = 'Methods'}
            <#
		    @{Class = 'XboxControllerInput'
		    Member = 'GetButton'
		    MemberType = 'Methods'}
            #>
        )
	}
	Compile = @{
		ReferencedAssemblies = 'mscorlib.dll', 'System.dll', 'UnityEngine.dll', 'J2i.Net.XInputWrapper.dll'
		CompilerVersion = 'v4.0'
		CompilerOptions = '/nostdlib'
	}
	Script = @{
		Dir = Split-Path $script:MyInvocation.MyCommand.Path
		Name = Split-Path $script:MyInvocation.MyCommand.Path -Leaf
	}
	Mapping = @{
		Default = @{
			0 = 'A'
			1 = 'B'
			2 = 'X'
			3 = 'Y'
			4 = 'LShoulder'
			5 = 'RShoulder'
			6 = 'Select'
			7 = 'Start'
			8 = 'LStick'
			9 = 'RStick'
			10 = 'LTrigger'
			11 = 'RTrigger'
		}
		Custom = $null
	}
    Pause = @{
        Msg = 'Press any key to continue...'
	    ExitMsg = 'Press any key to exit...'
        FColor = 'Yellow'
    }
	ReflexilAssembly = 'Mono.Cecil.Reflexil.dll'
}

#endregion

#region Startup

# Show banner text
$Banner.Ori | Show-Text -ForegroundColor Green -Center
$Banner.Tool | Show-Text -ForegroundColor Yellow -Center
Show-Text -Text '_' -ForegroundColor Cyan -AsSeparator

Write-Verbose "Script directory: $($Cfg.Script.Dir)"

# Load Mono.Cecil.Reflexil
Join-Path -Path $Cfg.Script.Dir -ChildPath $Cfg.ReflexilAssembly |
	ForEach-Object {
		Write-Verbose "Loading Mono.Cecil from: $_"
		try
		{
			Add-Type -Path $_ -ErrorAction Stop
		}
		catch
		{
			Write-Warning "Can''t load $($Cfg.ReflexilAssembly), press any key to exit..."
			Pause -Message $Cfg.Pause.ExitMsg $Cfg.Pause.FColor
			Exit
		}
	}

# Select patch mode
$Cfg.Patch.CurrentMode = Show-PatchModeMenu -Mode $Cfg.Patch.AvailableModes
Pause -Message $Cfg.Pause.Msg $Cfg.Pause.FColor

if($Cfg.Patch.CurrentMode -eq 'Remap')
{
    # Import custom controller mappings
    $Cfg.Mapping.Custom = Get-IniContent -FilePath (
	    Join-Path -Path $Cfg.Script.Dir -ChildPath ([System.IO.Path]::GetFileNameWithoutExtension($Cfg.Script.Name) + '.ini')
    )

    if(!$Cfg.Mapping.Custom)
    {
	    Write-Warning -Message 'No custom controller mappings found, exiting!'
	    Pause -Message $Cfg.Pause.ExitMsg $Cfg.Pause.FColor
	    Exit
    }

    # Select custom mapping
    $Cfg.Mapping.Custom = Show-ControllerMappingMenu -Custom $Cfg.Mapping.Custom
    Pause -Message $Cfg.Pause.Msg $Cfg.Pause.FColor
}

# Get Ori's install directory (or script directory, of Ori's files are there)
Write-Host "Searching for '$($Cfg.Game.Assembly)'" -ForegroundColor Cyan
$Cfg.Game.InstallDir = Get-GameAssemblyDirectory -Path $Cfg.Script.Dir -GameAssembly $Cfg.Game.Assembly

if(!$Cfg.Game.InstallDir)
{
	Write-Warning "Can't find $($Cfg.Game.Assembly) in $($Cfg.Game.InstallDir)"
	Pause -Message $Cfg.Pause.ExitMsg $Cfg.Pause.FColor
	Exit
}

# Check, if referenced assemblies are in the
# game directory, otherwise patch will fail.
Write-Host "Searching for referenced assemblies: $($Cfg.Compile.ReferencedAssemblies -join ', ')" -ForegroundColor Cyan
[array]$RefNotFound = $Cfg.Compile.ReferencedAssemblies | ForEach-Object {
	$FullPath = Join-Path -Path $Cfg.Game.InstallDir -ChildPath $_
	@{
		Path = $FullPath
		Exists = (Test-Path -Path $FullPath -PathType Leaf)
	}
} | Where-Object {!$_.Exists}

if($RefNotFound)
{
	Write-Warning 'Can''t find referenced assemblies:'
	($RefNotFound).Path | Write-Warning
	Pause -Message $Cfg.Pause.ExitMsg $Cfg.Pause.FColor
	Exit
}

# Update paths to reference assemblies to fully qualified
$Cfg.Compile.ReferencedAssemblies = $Cfg.Compile.ReferencedAssemblies |
	ForEach-Object {
		Join-Path -Path $Cfg.Game.InstallDir -ChildPath $_
	}

# Create backup
$GameAssemblyPath = Join-Path -Path $Cfg.Game.InstallDir -ChildPath $Cfg.Game.Assembly
$GameAssemblyBackupPath = $GameAssemblyPath + '.bak'
if(!(Test-Path -Path $GameAssemblyBackupPath -PathType Leaf))
{
	Write-Host "Creating backup: $GameAssemblyBackupPath" -ForegroundColor Cyan
	Copy-Item -Path $GameAssemblyPath -Destination $GameAssemblyBackupPath -Force
}
else
{
	Write-Host "Backup already exists: $GameAssemblyBackupPath" -ForegroundColor Cyan
}

Write-Host 'Applying patch...' -ForegroundColor Cyan

# Import original assembly with Mono.Cecil
$GameAssemblyDefinition = [Mono.Cecil.Reflexil.AssemblyDefinition]::ReadAssembly($GameAssemblyPath)

# Build assembly with patched methods
if($Cfg.Patch.CurrentMode -eq 'Remap')
{
    $SplatRIGBMS = $Cfg.Mapping + @{$Cfg.Patch.CurrentMode = $true}
}
elseif($Cfg.Patch.CurrentMode -eq 'Disable')
{
    $SplatRIGBMS = @{$Cfg.Patch.CurrentMode = $true}
}
else
{
	Write-Warning 'Unknown patch mode!'
	Pause -Message $Cfg.Pause.ExitMsg $Cfg.Pause.FColor
	Exit
}
$SplatNAFS = $Cfg.Compile
$PatchAssemblyPath = New-RawInputGetButtonMethodSource @SplatRIGBMS| New-GameAssemblySource | New-AssemblyFromSource @SplatNAFS

# Import patch assembly with Mono.Cecil
$PatchAssemblyDefinition = [Mono.Cecil.Reflexil.AssemblyDefinition]::ReadAssembly($PatchAssemblyPath)

if($PatchAssemblyDefinition -and $GameAssemblyDefinition)
{
	    try
	    {
	        $Cfg.Patch.Set | ForEach-Object {
	            # Get source\destination method for patch
                $SplatGCM = $_
	            $GameMethod = Get-ClassMember @SplatGCM -AssemblyDefinition $GameAssemblyDefinition
	            $PatchMethod = Get-ClassMember @SplatGCM -AssemblyDefinition $PatchAssemblyDefinition

                [Reflexil.Utils.CecilHelper]::PatchAssemblyNames(
                    $PatchMethod.Module,
                    'b77a5c561934e089', (New-Object -TypeName System.Version -ArgumentList @(2, 0, 0, 0)),
                    '7cec85d7bea7798e', (New-Object -TypeName System.Version -ArgumentList @(2, 0, 5, 0))
                )

		        # Replace method in original assembly with patched one, optimze and fix IL
		        [Reflexil.Utils.CecilHelper]::CloneMethodBody($PatchMethod, $GameMethod)#, $true)
                <#
                    CecilHelper.PatchAssemblyNames(
                        MethodDefinition.Module,
                        Compiler.MicrosoftPublicKeyToken, Compiler.MicrosoftVersion,
                        Compiler.UnitySilverLightPublicKeyToken, Compiler.UnitySilverLightVersion
                    );

                    [Reflexil.Utils.CecilHelper]::PatchAssemblyNames(
                        $PatchMethod.Module,
                        'b77a5c561934e089', (New-Object -TypeName System.Version -ArgumentList @(2, 0, 0, 0)),
                        '7cec85d7bea7798e', (New-Object -TypeName System.Version -ArgumentList @(2, 0, 5, 0)))
                #>

            }

		    # Save original assembly with patched method to disk
		    $GameAssemblyDefinition.Write($GameAssemblyPath)

		    # All done
		    Write-Host 'Success!' -ForegroundColor Cyan
	    }
	    catch
	    {
		    # Something went wrong...
		    Write-Warning 'Patch failed, see error messages above!'
	    }
}
else
{
	# Something went wrong...
	Write-Warning 'Patch failed, see error messages above!'

	# Restore backup
	Remove-Item $GameAssemblyPath -Force
	Copy-Item -Path $GameAssemblyBackupPath -Destination $GameAssemblyPath -Force
}

# Delete patch assembly
Remove-Item -Path $PatchAssemblyPath -Force

# Exit
Pause -Message $Cfg.Pause.ExitMsg $Cfg.Pause.FColor

#endregion