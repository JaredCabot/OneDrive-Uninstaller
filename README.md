# OneDrive-Uninstaller
A batch script to completely uninstall OneDrive in Windows 10 and 11.

# READ THIS STUFF, FOR REALS BROOO!!!
Download the latest 'OneDrive Uninstaller' batch file and run it as Administrator (right click the file, 'Run as Administrator').

Before you run it:
- Right-click your OneDrive folder and choose **Always keep on this device**. Online-only files can't be moved once OneDrive is gone.
- Sign out any other users. Explorer gets closed while it runs.
- On a work/school PC, check with IT first. The script warns you if the PC looks managed.

Want to see what it would do first? Run it from an admin command prompt with `/dryrun`. It logs every step and changes nothing.

Removing OneDrive WILL break access to existing OneDrive accounts. Set a restore point or take a drive image if you're unsure.

# What V2.1 does
For every account on the PC (including the Default profile that new accounts are copied from):
- Moves Desktop/Documents/Pictures/Music/Videos/Downloads back out of OneDrive if OneDrive redirected them. Only the folders that were actually redirected get touched.
- Renames each OneDrive folder (including business "OneDrive - Company" folders) to `<name> (backup)`. **Nothing in your OneDrive folder is deleted.**
- Removes OneDrive's settings, startup entries, File Explorer sidebar entries, environment variables and app files.

Then, machine-wide:
- Runs the OneDrive uninstallers (per-user and per-machine) and waits for them to finish.
- Removes the scheduled tasks, Active Setup entries, sync-root registrations, overlay icons, leftover files and uninstall entries.
- Clears cached OneDrive credentials for the account running the script.
- Sets the `DisableFileSyncNGSC` policy so OneDrive can't run. It doesn't stop Windows or Office updates from putting the installer back, but the policy stops it running if they do.

Every registry key is exported to a numbered `.reg` file before it's changed. Everything is logged to `C:\OneDrive-Uninstaller\run-N\`. Double-click a `.reg` file to undo that change.

# Heads up
When it finishes it tells you how many problems it hit (if any) and offers to reboot. Reboot so every change takes effect. If it reported locked files, run it once more after the reboot.

After you sign back in, an empty `HKCU\Software\Microsoft\OneDrive` registry key may show up again. That's Windows Security (`SecurityHealthService.exe`) checking whether OneDrive is installed, and the check creates the key as a side effect. It's not OneDrive coming back. It's harmless, so leave it alone.

Let me know if you find a bug or want any features. Find me on Reddit or something.

Peace out.
