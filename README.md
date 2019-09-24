# Tunnel
AppleScript applet to open SSH tunnels.

## Motivation
Feeling very reluctant to use screen sharing solutions by third parties like TeamViewer and Anydesk, I decided to automate the opening of SSH tunnels. This way anyone can start a connection to a server controlled by me, which I could then use to access their Macs.

## Building the applet

1. Download or clone this repository

2. Run the build script

3. When prompted, choose to save and edit the sample settings

4. Fill out the settings

5. Run the build script again

6. When asked choose to generate new key pair

6. The built applet will be shown in the Finder

## Running the applet

1. A dialog is shown so the user can confirm the connection

2. The SSH tunnel is opened

3. When connected, a dialog shows the tunneled port number on the SSH server

4. The applet stays open to monitor the SSH process and starts it again if necessary

5. When the applet is quit regularly, the SSH connection is ended

## Connecting through tunnel

If you left the local port set to 5900, you can connect via VNC like this:

1. From the Finder’s **Go** menu, select the **Connect to server** 

2. Enter **vnc://** followed by the SSH server’s address, a colon, and the tunneled port number (Example: vnc://ssh.mydomain.com:58834)

3. Click **Connect**

## Server requirements

- SSH service turned on and accessible to the user specified in the applet’s build settings

- SSH service reachable at the address and port specified in the applet’s build settings

- Ports 50000 through 59999 accessible to your Mac so you can connect back through the tunnel

- Corresponding public key entered in authorized_keys file prefixed with `command="/sbin/nologin" ` (note the space at the end of this prefix that needs to delimit it from the key). You will find the public key in ~/Library/Application Support/Tunnel/Keys/.

- Suggested SSH server configuration options:
```PasswordAuthentication no
PermitEmptyPasswords no
ChallengeResponseAuthentication no
UsePAM no
GatewayPorts yes
```
- The option `GatewayPorts yes` is particularly important so you can access tunneled ports on the SSH server

## Development notes

- When running the tunnel script from your editor, you can prepare a settings file at the path ~/Library/Application Support/Tunnel/Settings/testing.applescript for testing purposes