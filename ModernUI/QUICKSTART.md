# ⚡ Quick Start - Get ModernUI Running in 5 Minutes

## Prerequisites

- Windows 10 or 11
- PowerShell 7.0+ (or 5.1 with .NET 4.8)
- .NET Framework 4.8+
- Git (optional, for cloning)

---

## Step 1: Get the Code (1 min)

### Option A: Clone with Git

```powershell
git clone https://github.com/praetoriani/PowerShell.Lib.git
cd PowerShell.Lib\ModernUI
```

### Option B: Download ZIP

1. Visit [GitHub Repository](https://github.com/praetoriani/PowerShell.Lib)
2. Click Code → Download ZIP
3. Extract and navigate to `PowerShell.Lib\ModernUI`

---

## Step 2: Verify Files (1 min)

Make sure you have these files:

```
ModernUI/
├── ModernUI.ps1              ✓ Required
├── config.json               ✓ Required
├── ModernUI.xaml             ✓ Required
└── PNG/                       ✓ Required
    ├── appicon.png
    ├── ModernUI-WinBG.png
    ├── axn-winclose-normal.png
    └── axn-winclose-hover.png
```

**Missing files?** Something went wrong with the download/clone.

---

## Step 3: Check Execution Policy (1 min)

Open PowerShell and check:

```powershell
Get-ExecutionPolicy
```

If it shows `Restricted`, run:

```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

---

## Step 4: Run ModernUI (1 min)

```powershell
.\ModernUI.ps1
```

**Expected output:**
- Window appears immediately
- Dark-themed UI with "ModernUI" title
- Close button (X) visible in title bar
- Background image with waves
- No error messages

---

## Step 5: Test (1 min)

### Click Title Bar
- Drag the window around
- Release to drop

### Hover Close Button
- Tooltip appears: "Close Application"
- Button changes color on hover

### Click Close Button
- Window closes cleanly
- No errors in console

---

## ✅ Success!

If you see all of the above, **ModernUI is working perfectly!** 🎉

---

## Common Issues

### Issue: "ModernUI.ps1 cannot be loaded"

**Solution:** Check execution policy

```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

### Issue: "File not found" errors

**Solution:** Make sure you're in the correct directory

```powershell
cd PowerShell.Lib\ModernUI
ls  # Should show ModernUI.ps1, config.json, PNG folder, etc.
```

### Issue: Window doesn't appear

**Solution:** Check .NET Framework version

```powershell
[System.Runtime.InteropServices.RuntimeInformation]::FrameworkDescription
```

Should show `.NET Framework 4.8+` or `.NET 5.0+`

### Issue: "Cannot find PNG images"

**Solution:** Verify PNG folder exists and contains images

```powershell
ls .\PNG\  # Should list all PNG files
```

### Issue: Config.json errors

**Solution:** Check JSON is valid

```powershell
(Get-Content config.json) | ConvertFrom-Json
```

If no error, JSON is valid.

---

## Next Steps

### Learn More
- Read [README.md](./README.md) for full documentation
- Check [CHANGELOG.md](./CHANGELOG.md) for version history
- See [BUGFIXES.md](./BUGFIXES.md) for technical details

### Customize
- Edit `config.json` to change image paths
- Replace PNG files with your own graphics
- Modify `ModernUI.ps1` to add functionality

### Share
- Star the [GitHub repository](https://github.com/praetoriani/PowerShell.Lib)
- Share with colleagues
- Create issues for bugs or feature requests

---

## Getting Help

### Still stuck?

1. Check [README.md FAQ](./README.md#faq) section
2. Review [BUGFIXES.md](./BUGFIXES.md) for known issues
3. Search [GitHub Issues](https://github.com/praetoriani/PowerShell.Lib/issues)
4. Create a new issue with:
   - Your OS version
   - PowerShell version (`$PSVersionTable`)
   - Error message (copy full error)

### Contact

- Email: marc.sczepanski@gmail.com
- GitHub: [@praetoriani](https://github.com/praetoriani)

---

**Done! Enjoy ModernUI! 🚀**
