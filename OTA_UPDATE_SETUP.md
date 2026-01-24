# OTA Update Backend API Example

This example shows how to implement the backend API endpoint for OTA updates.

## API Endpoint: `/api/app-version`

### Response Format (JSON)

```json
{
  "version": "1.0.1",
  "build_number": "2",
  "force_update": false,
  "download_url": "https://your-app-store-url.com",
  "release_notes": "- Bug fixes\n- Performance improvements\n- New features added",
  "min_supported_version": "1.0.0",
  "platform": "android|ios|both"
}
```

## Node.js/Express Example

```javascript
// routes/app-version.js
const express = require('express');
const router = express.Router();

// In production, store this in a database
const appVersions = {
  android: {
    version: '1.0.1',
    build_number: '2',
    force_update: false,
    download_url: 'https://play.google.com/store/apps/details?id=com.yourapp.territoryFitness',
    release_notes: '- Bug fixes\n- Performance improvements\n- New territory capture algorithm',
    min_supported_version: '1.0.0'
  },
  ios: {
    version: '1.0.1',
    build_number: '2',
    force_update: false,
    download_url: 'https://apps.apple.com/app/your-app-id',
    release_notes: '- Bug fixes\n- Performance improvements\n- New territory capture algorithm',
    min_supported_version: '1.0.0'
  }
};

router.get('/app-version', (req, res) => {
  const platform = req.query.platform || 'android';
  const currentVersion = req.query.current_version;
  
  const versionInfo = appVersions[platform] || appVersions.android;
  
  // Check if force update is needed based on min supported version
  if (currentVersion && isVersionLessThan(currentVersion, versionInfo.min_supported_version)) {
    versionInfo.force_update = true;
  }
  
  res.json(versionInfo);
});

function isVersionLessThan(version1, version2) {
  const v1Parts = version1.split('.').map(Number);
  const v2Parts = version2.split('.').map(Number);
  
  for (let i = 0; i < 3; i++) {
    const v1 = v1Parts[i] || 0;
    const v2 = v2Parts[i] || 0;
    if (v1 < v2) return true;
    if (v1 > v2) return false;
  }
  return false;
}

module.exports = router;
```

## Django/Python Example

```python
# views.py
from django.http import JsonResponse
from django.views import View

class AppVersionView(View):
    def get(self, request):
        platform = request.GET.get('platform', 'android')
        current_version = request.GET.get('current_version')
        
        versions = {
            'android': {
                'version': '1.0.1',
                'build_number': '2',
                'force_update': False,
                'download_url': 'https://play.google.com/store/apps/details?id=com.yourapp.territoryFitness',
                'release_notes': '- Bug fixes\n- Performance improvements\n- New territory capture algorithm',
                'min_supported_version': '1.0.0'
            },
            'ios': {
                'version': '1.0.1',
                'build_number': '2',
                'force_update': False,
                'download_url': 'https://apps.apple.com/app/your-app-id',
                'release_notes': '- Bug fixes\n- Performance improvements\n- New territory capture algorithm',
                'min_supported_version': '1.0.0'
            }
        }
        
        version_info = versions.get(platform, versions['android'])
        
        # Check if force update is needed
        if current_version and self.is_version_less_than(current_version, version_info['min_supported_version']):
            version_info['force_update'] = True
        
        return JsonResponse(version_info)
    
    def is_version_less_than(self, version1, version2):
        v1_parts = [int(x) for x in version1.split('.')]
        v2_parts = [int(x) for x in version2.split('.')]
        
        for i in range(3):
            v1 = v1_parts[i] if i < len(v1_parts) else 0
            v2 = v2_parts[i] if i < len(v2_parts) else 0
            if v1 < v2:
                return True
            if v1 > v2:
                return False
        return False
```

## Usage in Your Existing Backend

If you're using the backend in the `backend/` folder, add this endpoint to your existing API server.

## Configuration

Update the `updateCheckUrl` in `lib/core/services/update_service.dart`:

```dart
static const String updateCheckUrl = 'https://your-backend.com/api/app-version';
```

## Testing

You can test the update flow by:
1. Changing the version in the backend response to a higher version
2. Running the app and triggering the update check
3. Verifying the update dialog appears

## Production Deployment

1. Deploy the backend API endpoint
2. Update the `updateCheckUrl` in the Flutter app
3. Configure force_update flag for critical updates
4. Update download_url with actual app store links
