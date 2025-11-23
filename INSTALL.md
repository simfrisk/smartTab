# Installing SmartTab on Your Mac

This guide will help you build and install SmartTab as a proper macOS application.

## Method 1: Quick Install (Recommended)

### Step 1: Build the App in Xcode

1. **Open the project**:

   ```bash
   open SmartTab/SmartTab.xcodeproj
   ```

2. **Build the app**:

   - In Xcode, press **⌘B** (or Product → Build)
   - Wait for the build to complete successfully

3. **Find the built app**:
   - In Xcode, go to **Product** → **Show Build Folder in Finder**
   - Navigate to: `Build/Products/Debug/SmartTab.app`
   - Or use: **⌘⇧K** to clean, then **⌘B** to build, then right-click on `SmartTab.app` in the Products folder → **Show in Finder**

### Step 2: Install to Applications

1. **Copy to Applications**:

   - Drag `SmartTab.app` from the build folder to your `/Applications` folder
   - Or copy it: `cp -R SmartTab.app /Applications/`

2. **First Launch**:

   - Open **Applications** folder in Finder
   - Double-click **SmartTab.app** to launch it
   - macOS may warn you about an unidentified developer - click **Open** anyway

3. **Grant Permissions**:
   - macOS will prompt for **Accessibility** permissions
   - Go to **System Settings** → **Privacy & Security** → **Accessibility**
   - Find **SmartTab** and enable the toggle
   - Restart the app (quit and relaunch)

### Step 3: Launch at Login (Optional)

To make SmartTab start automatically when you log in:

1. **System Settings** → **General** → **Login Items**
2. Click the **+** button
3. Navigate to `/Applications/SmartTab.app` and add it
4. Make sure the toggle next to SmartTab is enabled

## Method 2: Archive and Export (For Distribution-Ready Build)

This creates a properly signed and optimized build:

1. **Open Xcode** and select the project

2. **Set up Signing** (if not already done):

   - Select the **SmartTab** target
   - Go to **Signing & Capabilities** tab
   - Select your **Team** (or "None" for local use)
   - Xcode will automatically manage signing

3. **Archive the app**:

   - In Xcode menu: **Product** → **Archive**
   - Wait for the archive to complete
   - The Organizer window will open

4. **Export the app**:

   - In the Organizer, click **Distribute App**
   - Choose **Copy App** (for local installation)
   - Click **Next** → **Export**
   - Choose a location (e.g., Desktop)
   - Click **Export**

5. **Install**:
   - Drag the exported `SmartTab.app` to `/Applications`
   - Launch and grant permissions as described above

## Method 3: Command Line Build Script

You can also create a simple script to build and install:

```bash
#!/bin/bash
# Build and install SmartTab

cd "$(dirname "$0")"

# Build using xcodebuild
xcodebuild -project SmartTab/SmartTab.xcodeproj \
           -scheme SmartTab \
           -configuration Release \
           -derivedDataPath ./build

# Copy to Applications
cp -R ./build/Build/Products/Release/SmartTab.app /Applications/

echo "SmartTab installed to /Applications!"
echo "Don't forget to grant Accessibility permissions in System Settings!"
```

Save this as `install.sh`, make it executable (`chmod +x install.sh`), and run it.

## Updating

When you make changes to SmartTab and want to update the installed version:

### Quick Update (Using Script)

Run the update script from the project directory:

```bash
./update.sh
```

This will:

- Quit SmartTab if it's running
- Build the latest version
- Replace the app in `/Applications`
- Optionally launch the updated version

### Manual Update

1. **Quit the app** (if running):

   - Right-click the menu bar icon → Quit
   - Or: Activity Monitor → Find SmartTab → Quit

2. **Build in Xcode**:

   - Open `SmartTab/SmartTab.xcodeproj` in Xcode
   - Press **⌘B** to build
   - Or use: `xcodebuild -project SmartTab/SmartTab.xcodeproj -scheme SmartTab -configuration Release`

3. **Replace the app**:

   - Find the built app (usually in `Build/Products/Release/SmartTab.app`)
   - Delete the old version: `rm -rf /Applications/SmartTab.app`
   - Copy the new version: `cp -R SmartTab.app /Applications/`

4. **Launch the updated app**:
   - Open from Applications or Spotlight
   - No need to re-grant permissions (they persist)

## Verification

After installation:

1. ✅ App appears in `/Applications` folder
2. ✅ Can launch from Applications or Spotlight (⌘Space, type "SmartTab")
3. ✅ App runs in background (check menu bar)
4. ✅ Hotkey works (⌘` to open launcher)
5. ✅ Accessibility permissions granted

## Troubleshooting

**"SmartTab cannot be opened because it is from an unidentified developer"**

- Right-click the app → **Open** → Click **Open** in the dialog
- Or: System Settings → Privacy & Security → Allow apps downloaded from: **App Store and identified developers**

**Hotkey doesn't work**

- Make sure Accessibility permissions are granted
- Restart the app after granting permissions
- Check System Settings → Privacy & Security → Accessibility

**App won't launch**

- Check Console.app for error messages
- Make sure you're running macOS 12.0 or later
- Try rebuilding in Xcode

## Uninstalling

### Quick Uninstall (Using Script)

Run the uninstall script from the project directory:

```bash
./uninstall.sh
```

This will:

- Quit the app if it's running
- Remove SmartTab.app from /Applications
- Show instructions for manual cleanup

### Manual Uninstall

To remove SmartTab manually:

1. **Quit the app** (if running):

   - Right-click the menu bar icon → Quit
   - Or: Activity Monitor → Find SmartTab → Quit

2. **Remove from Login Items**:

   - System Settings → General → Login Items
   - Find SmartTab and click the **−** button to remove it

3. **Delete the app**:

   - Open Finder → Applications
   - Find SmartTab.app
   - Drag it to Trash, or right-click → Move to Trash
   - Or use Terminal: `rm -rf /Applications/SmartTab.app`

4. **Remove Accessibility permission** (optional):

   - System Settings → Privacy & Security → Accessibility
   - Find SmartTab in the list
   - Click the **−** button to remove it, or just toggle it off

5. **Empty Trash** (if you moved it there):
   - Right-click Trash → Empty Trash
