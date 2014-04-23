$code = @"
using System;
using System.Text;
using System.Runtime.InteropServices;
using Microsoft.Win32.SafeHandles;
using System.ComponentModel;

namespace SymLinkInterop {
	public sealed class SymLinkManager
	{
		private const int FILE_SHARE_READ = 1;
		private const int FILE_SHARE_WRITE = 2;

		private const int CREATION_DISPOSITION_OPEN_EXISTING = 3;

		private const int FILE_FLAG_BACKUP_SEMANTICS = 0x02000000;

		[DllImport("kernel32.dll", EntryPoint = "GetFinalPathNameByHandleW", CharSet = CharSet.Unicode, SetLastError = true)]
		public static extern int GetFinalPathNameByHandle(IntPtr handle, [In, Out] StringBuilder path, int bufLen, int flags);

		[DllImport("kernel32.dll", EntryPoint = "CreateFileW", CharSet = CharSet.Unicode, SetLastError = true)]
		public static extern SafeFileHandle CreateFile(string lpFileName, int dwDesiredAccess, int dwShareMode,
		IntPtr SecurityAttributes, int dwCreationDisposition, int dwFlagsAndAttributes, IntPtr hTemplateFile);

		public static string GetSymbolicLinkTarget(string symlinkpath)
		{
			SafeFileHandle directoryHandle = CreateFile(symlinkpath, 0, 2, System.IntPtr.Zero, CREATION_DISPOSITION_OPEN_EXISTING, FILE_FLAG_BACKUP_SEMANTICS, System.IntPtr.Zero);
			if(directoryHandle.IsInvalid)
				throw new Win32Exception(Marshal.GetLastWin32Error());

			StringBuilder path = new StringBuilder(512);
			int size = GetFinalPathNameByHandle(directoryHandle.DangerousGetHandle(), path, path.Capacity, 0);
			if (size<0)
				throw new Win32Exception(Marshal.GetLastWin32Error());
			if (path[0] == '\\' && path[1] == '\\' && path[2] == '?' && path[3] == '\\')
				return path.ToString().Substring(4);
			else
				return path.ToString();
		}
	}
}
"@

Add-Type -TypeDefinition $code

function Get-SymbolicLinkTarget
{
    [CmdletBinding()]
    param
    (
        [parameter(Mandatory=$true, ValueFromPipeline=$true)]
        [string]$Path
    )
    PROCESS
    {
		return [SymLinkInterop.SymLinkManager]::GetSymbolicLinkTarget($Path)
	}
}
