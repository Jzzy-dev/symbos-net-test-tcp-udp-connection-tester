# Net Test for SymbOS

<a href="https://msx.pics/image/x4VGP"><img src="https://msx.pics/images/2026/10/14/net-test1.md.jpeg" alt="net test1" border="0"></a>

<a href="https://msx.pics/image/xtisp"><img src="https://msx.pics/images/2026/10/14/net-test2.md.jpeg" alt="net test2" border="0"></a>

<a href="https://msx.pics/image/x4SNT"><img src="https://msx.pics/images/2026/10/14/net-test3.md.jpeg" alt="net test3" border="0"></a>

Small test program for the Network Daemon (also works with other daemon drivers).

* World clock - SNTP over UDP, port 123. Shows the city picked in the list and the raw UTC time with seconds.
  Local time and summer time (EU, US, Australia, New Zealand rules) are calculated in the program. A * behind
  the time means that daylight saving time (summer time) is active in that city. The result also shows what
  was sent to which server, the IP address that was asked and the stratum of the answer. The request goes to
  pool.ntp.org first, then to time.google.com and time.cloudflare.com, each with up to three sends.
  The date of the city is copied into the date fields.
* HTTPS check box (top right) - Weather and Sun times then connect to port 443 instead of 80. The daemon driver
  (v0.5 or newer) turns port 443 into a TLS connection in the ESP, the program still sends plain HTTP. The line
  above the HTTP status shows GET host:port, with TLS added when HTTPS is on. The first HTTPS request needs a few
  seconds more for the handshake.
* Weather - HTTP over TCP to wttr.in, one short line (condition, temperature, wind, humidity).
* Sun times - HTTP over TCP to api.sunrise-sunset.org, sunrise, solar noon, sunset and day length
  in the local time of the city. The three fields are year, month and day (YYYY MM DD), all empty means today.
  The last line always shows the first line of the server answer (for example HTTP/1.1 200 OK),
  so a redirect or error page is easy to recognise. The line above it shows what was sent.

## Build in WinAPE 1.0.13
Put these files in the symnet folder
* NetTest.asm (wrapper, assemble this one)
* NetTest-head.asm
* NetTest-code.asm
* Dmn-Network-libs.asm (already there from the driver package)

The wrapper writes C:\Users\flcle\Downloads\symnet\nettest.exe and reads the constants from SRC-Main
like the driver wrapper does. Start the Network Daemon first, then nettest.exe.

## Notes
* The World clock button is also the UDP test of the daemon. If it fails, the last characters of the message (for example U03) are the stage letter and the status for diagnosis.
* The program waits for the network while a request runs, the window does not react until it is finished.
  Time outs are about 25 seconds for TCP and a few seconds per try for SNTP (3 tries).
* Plain HTTP unless the HTTPS box is ticked. If a service answers with a redirect to https the last line shows it,
  tick the box and try again.
* Summer time uses today's rules (Mexico and Brazil have none any more).
