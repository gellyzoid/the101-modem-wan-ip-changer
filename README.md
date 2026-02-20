# the101 5G Modem Controller

A Flutter mobile application for managing WAN IP refresh on the101 5G modem without needing to access the router's web dashboard.

<p align="center">
  <img src="https://img.shields.io/badge/Flutter-02569B?style=for-the-badge&logo=flutter&logoColor=white" alt="Flutter">
  <img src="https://img.shields.io/badge/Dart-0175C2?style=for-the-badge&logo=dart&logoColor=white" alt="Dart">
  <img src="https://img.shields.io/badge/Android-3DDC84?style=for-the-badge&logo=android&logoColor=white" alt="Android">
</p>

## Overview

**the101 5G Modem Controller** is a mobile app designed to manage WAN IP refresh operations on the101 5G cellular router. This app eliminates the need to log into the router's web dashboard, providing a streamlined mobile experience for IP management.

### What is the101?

the101 is a 5G cellular router that uses SIM cards to provide internet connectivity. The device supports multiple network modes (RAT modes) that can be toggled to refresh the WAN IP address and restore internet connectivity when issues occur.

### Why This App?

- **Convenience:** Refresh your WAN IP directly from your phone
- **No Browser Needed:** Bypass the router's web interface
- **Real-time Monitoring:** View current and previous IP addresses
- **Automated Recovery:** Automatically retries network mode changes until internet is restored
- **Detailed Logging:** System logs show exactly what's happening during the refresh process

## ✨ Features

- **One-Tap IP Refresh** - Instantly refresh your WAN IP with a single button
- **IP Address Tracking** - View current and previous IP addresses
- **Automatic Retry Logic** - Up to 10 attempts to restore internet connectivity
- **Network Mode Toggling** - Automatically switches between RAT modes 19 and 21
- **Internet Connectivity Check** - Verifies Google accessibility after each attempt
- **Real-time System Logs** - Monitor the refresh process with detailed logging
- **Beautiful UI** - Clean, modern interface with gradient design
- **SSL Support** - Handles self-signed certificates seamlessly

## Getting Started

### Prerequisites

- Flutter SDK (3.0 or higher)
- Android device connected to the101 router's WiFi network
- the101 5G modem with admin credentials

### Installation

1. **Clone the repository:**

   ```bash
   git clone https://github.com/yourusername/router_control_flutter.git
   cd router_control_flutter
   ```

2. **Install dependencies:**

   ```bash
   flutter pub get
   ```

3. **Configure router credentials** (optional):

   Edit `lib/main.dart` and update the login credentials if different from defaults:

   ```dart
   body: 'username=YOUR_USERNAME&password=YOUR_PASSWORD',
   ```

4. **Build the APK:**

   ```bash
   flutter build apk --release
   ```

5. **Install on your Android device:**

   The APK will be located at:

   ```
   build/app/outputs/flutter-apk/app-release.apk
   ```

## Usage

1. **Connect to Router WiFi:**
   - Ensure your Android device is connected to the101 router's WiFi network
   - The default router IP is `192.168.0.1`

2. **Launch the App:**
   - Open the101 5G Modem Controller app

3. **View Current IP:**
   - The app automatically fetches and displays your current WAN IP on startup

4. **Refresh WAN IP:**
   - Tap the "Refresh WAN IP" button
   - Confirm the action in the dialog
   - Wait 1-2 minutes for the process to complete

5. **Monitor Progress:**
   - View real-time logs in the System Logs panel
   - See the number of attempts and final results

## How It Works

The app performs the following steps when refreshing the WAN IP:

1. **Login** - Authenticates with the router using admin credentials
2. **Get Current IP** - Retrieves the current WAN IP address
3. **Check Network Mode** - Determines the current RAT mode (19 or 21)
4. **Toggle Mode** - Switches to the alternate RAT mode
5. **Wait & Retry** - Waits 10 seconds and checks internet connectivity
6. **Repeat** - Continues toggling and checking up to 10 times
7. **Report** - Displays final results (IP changed, internet accessible, attempts)

### Network Modes (RAT Modes)

- **Mode 19:** LTE-only mode
- **Mode 21:** 5G/LTE mode

Toggling between these modes forces the router to reconnect, potentially assigning a new IP address.

## Technical Details

### Built With

- **Flutter** - UI framework
- **Dart** - Programming language
- **http package** - HTTP requests to router API

### Router API Endpoints

- `POST /cgi-bin/login.cgi` - Authentication
- `GET /cgi-bin/devinfo.cgi` - Device information (WAN IP)
- `GET /cgi-bin/netmoderat.cgi` - Current network mode
- `POST /cgi-bin/netmode.cgi` - Set network mode

### SSL Certificate Handling

The app handles the router's self-signed SSL certificate using a custom `HttpOverrides`:

```dart
class MyHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)
      ..badCertificateCallback = (X509Certificate cert, String host, int port) => true;
  }
}
```

## ⚙️ Configuration

### Router Settings

Default router configuration:

- **IP Address:** `192.168.0.1`
- **Protocol:** HTTPS
- **Port:** 443 (default HTTPS)

### App Settings

You can modify the following in `lib/main.dart`:

- **Max Retry Attempts:** Change `maxAttempts` value (default: 10)
- **Wait Time:** Modify `Duration(seconds: 10)` (default: 10 seconds)
- **Router Credentials:** Update username and password in the login function

## Requirements

- **Android:** 5.0 (API 21) or higher
- **Network:** Connected to the101 router's WiFi
- **Router Access:** Admin credentials for the101 router

1. Fork the project
2. Create your feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Support

If you encounter any issues or have questions:

- Open an issue on GitHub
- Check existing issues for solutions

## Future Enhancements

- [ ] iOS support
- [ ] Multiple router profiles
- [ ] Scheduled automatic refresh
- [ ] Network speed test integration
- [ ] Data usage monitoring
- [ ] Push notifications for IP changes
- [ ] Dark/Light theme toggle
- [ ] Language localization

## Additional Resources

- [Flutter Documentation](https://docs.flutter.dev/)
- [Dart Documentation](https://dart.dev/guides)
- [the101 Router Manual](https://example.com) _(link to actual manual if available)_

---
