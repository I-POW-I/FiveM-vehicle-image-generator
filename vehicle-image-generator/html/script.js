let vehicleCategories = [];
let isCapturing = false;
let selectedVehicles = [];
let isPreviewActive = false;
let originalCameraSettings = {};
let currentCameraSettings = {};

// Initialize
window.addEventListener('message', function(event) {
    const data = event.data;
    
    if (data.action === 'open') {
        document.body.classList.add('visible');
        vehicleCategories = data.vehicles || [];
        loadVehicles();
        
        // Load saved webhook
        if (data.webhook) {
            document.getElementById('webhookInput').value = data.webhook;
        }

        // Load camera settings from config
        if (data.cameraSettings) {
            originalCameraSettings = JSON.parse(JSON.stringify(data.cameraSettings));
            currentCameraSettings = JSON.parse(JSON.stringify(data.cameraSettings));
            loadCameraSettings(currentCameraSettings);
        }
    } else if (data.action === 'close') {
        document.body.classList.remove('visible');
    } else if (data.action === 'updateProgress') {
        updateProgress(data.current, data.total, data.vehicleName);
    } else if (data.action === 'captureComplete') {
        captureComplete();
    }
});

// Load vehicles into grid
function loadVehicles() {
    const grid = document.getElementById('vehicleGrid');
    grid.innerHTML = '';
    
    vehicleCategories.forEach(vehicle => {
        const checkbox = document.createElement('div');
        checkbox.className = 'vehicle-checkbox';
        checkbox.innerHTML = `
            <input type="checkbox" id="vehicle_${vehicle.id}" value="${vehicle.id}">
            <label for="vehicle_${vehicle.id}">${vehicle.label}</label>
        `;
        grid.appendChild(checkbox);
        
        // Add click event to the whole div
        checkbox.addEventListener('click', function(e) {
            if (e.target.tagName !== 'INPUT') {
                const input = checkbox.querySelector('input');
                input.checked = !input.checked;
            }
        });
    });
}

// Close button
document.getElementById('closeBtn').addEventListener('click', function() {
    // Close UI immediately
    document.body.classList.remove('visible');
    
    // Then notify client to release focus
    fetch(`https://vehicle-image-generator/close`, {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json'
        },
        body: JSON.stringify({})
    });
});

// Test webhook
document.getElementById('testWebhook').addEventListener('click', function() {
    const webhook = document.getElementById('webhookInput').value.trim();
    
    if (!webhook) {
        showNotification('Please enter a webhook URL', 'error');
        return;
    }
    
    if (!webhook.includes('discord.com/api/webhooks/')) {
        showNotification('Invalid Discord webhook URL', 'error');
        return;
    }
    
    fetch(`https://vehicle-image-generator/testWebhook`, {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json'
        },
        body: JSON.stringify({ webhook: webhook })
    });
});

// Select all
document.getElementById('selectAll').addEventListener('click', function() {
    const checkboxes = document.querySelectorAll('.vehicle-checkbox input[type="checkbox"]');
    checkboxes.forEach(cb => cb.checked = true);
});

// Deselect all
document.getElementById('deselectAll').addEventListener('click', function() {
    const checkboxes = document.querySelectorAll('.vehicle-checkbox input[type="checkbox"]');
    checkboxes.forEach(cb => cb.checked = false);
});

// Start capture
document.getElementById('startCapture').addEventListener('click', function() {
    const webhook = document.getElementById('webhookInput').value.trim();
    const checkboxes = document.querySelectorAll('.vehicle-checkbox input[type="checkbox"]:checked');
    
    if (!webhook) {
        showNotification('Please enter a webhook URL', 'error');
        return;
    }
    
    if (!webhook.includes('discord.com/api/webhooks/')) {
        showNotification('Invalid Discord webhook URL', 'error');
        return;
    }
    
    if (checkboxes.length === 0) {
        showNotification('Please select at least one vehicle', 'error');
        return;
    }

    // Stop preview mode if active before starting capture
    if (isPreviewActive) {
        isPreviewActive = false;
        document.getElementById('previewBtn').classList.remove('active');
        document.getElementById('previewBtn').innerHTML = '<span class="btn-icon">👁</span>PREVIEW';
        stopPreview();
    }
    
    selectedVehicles = [];
    checkboxes.forEach(cb => {
        const vehicleId = cb.value;
        const vehicle = vehicleCategories.find(v => v.id === vehicleId);
        if (vehicle) {
            selectedVehicles.push(vehicle);
        }
    });
    
    isCapturing = true;
    document.getElementById('startCapture').disabled = true;
    document.getElementById('stopCapture').disabled = false;
    document.getElementById('progressSection').style.display = 'block';

    // Get current camera settings (in case user modified them)
    const cameraSettings = getCurrentCameraSettings();
    
    fetch(`https://vehicle-image-generator/startCapture`, {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json'
        },
        body: JSON.stringify({
            webhook: webhook,
            vehicles: selectedVehicles,
            cameraSettings: cameraSettings
        })
    });
});

// Stop capture
document.getElementById('stopCapture').addEventListener('click', function() {
    isCapturing = false;
    document.getElementById('startCapture').disabled = false;
    document.getElementById('stopCapture').disabled = true;
    
    fetch(`https://vehicle-image-generator/stopCapture`, {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json'
        },
        body: JSON.stringify({})
    });
});

// Update progress
function updateProgress(current, total, vehicleName) {
    const percentage = (current / total) * 100;
    document.getElementById('progressFill').style.width = percentage + '%';
    document.getElementById('progressText').textContent = `${current} / ${total} vehicles captured - ${vehicleName}`;
}

// Capture complete
function captureComplete() {
    isCapturing = false;
    document.getElementById('startCapture').disabled = false;
    document.getElementById('stopCapture').disabled = true;
    showNotification('Capture completed successfully!', 'success');
}

// Show notification (sent to client)
function showNotification(message, type) {
    fetch(`https://vehicle-image-generator/notify`, {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json'
        },
        body: JSON.stringify({
            message: message,
            type: type
        })
    });
}

// Get parent resource name
function GetParentResourceName() {
    return 'vehicle-image-generator';
}

// ESC to close
document.addEventListener('keydown', function(event) {
    if (event.key === 'Escape') {
        // Close UI immediately
        document.body.classList.remove('visible');
        
        // Then notify client
        fetch(`https://vehicle-image-generator/close`, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json'
            },
            body: JSON.stringify({})
        });
    }
});

// Initialize buttons state
document.getElementById('stopCapture').disabled = true;

// ========================================
// CAMERA SETTINGS FUNCTIONALITY
// ========================================

// Load camera settings into UI
function loadCameraSettings(settings) {
    // Spawn coords
    document.getElementById('spawnX').value = settings.coords.x;
    document.getElementById('spawnXSlider').value = settings.coords.x;
    document.getElementById('spawnY').value = settings.coords.y;
    document.getElementById('spawnYSlider').value = settings.coords.y;
    document.getElementById('spawnZ').value = settings.coords.z;
    document.getElementById('spawnZSlider').value = settings.coords.z;

    // Heading
    document.getElementById('heading').value = settings.heading;
    document.getElementById('headingSlider').value = settings.heading;

    // Camera offset
    document.getElementById('camOffsetX').value = settings.cameraOffset.x;
    document.getElementById('camOffsetXSlider').value = settings.cameraOffset.x;
    document.getElementById('camOffsetY').value = settings.cameraOffset.y;
    document.getElementById('camOffsetYSlider').value = settings.cameraOffset.y;
    document.getElementById('camOffsetZ').value = settings.cameraOffset.z;
    document.getElementById('camOffsetZSlider').value = settings.cameraOffset.z;

    // Camera rotation
    document.getElementById('camRotX').value = settings.cameraRotation.x;
    document.getElementById('camRotXSlider').value = settings.cameraRotation.x;
    document.getElementById('camRotY').value = settings.cameraRotation.y;
    document.getElementById('camRotYSlider').value = settings.cameraRotation.y;
    document.getElementById('camRotZ').value = settings.cameraRotation.z;
    document.getElementById('camRotZSlider').value = settings.cameraRotation.z;

    // FOV
    document.getElementById('fov').value = settings.fov;
    document.getElementById('fovSlider').value = settings.fov;
}

// Get current camera settings from UI
function getCurrentCameraSettings() {
    return {
        coords: {
            x: parseFloat(document.getElementById('spawnX').value),
            y: parseFloat(document.getElementById('spawnY').value),
            z: parseFloat(document.getElementById('spawnZ').value)
        },
        heading: parseFloat(document.getElementById('heading').value),
        cameraOffset: {
            x: parseFloat(document.getElementById('camOffsetX').value),
            y: parseFloat(document.getElementById('camOffsetY').value),
            z: parseFloat(document.getElementById('camOffsetZ').value)
        },
        cameraRotation: {
            x: parseFloat(document.getElementById('camRotX').value),
            y: parseFloat(document.getElementById('camRotY').value),
            z: parseFloat(document.getElementById('camRotZ').value)
        },
        fov: parseFloat(document.getElementById('fov').value)
    };
}

// Sync slider and input
function syncInputs(inputId, sliderId) {
    const input = document.getElementById(inputId);
    const slider = document.getElementById(sliderId);

    input.addEventListener('input', function() {
        const value = parseFloat(this.value);
        const min = parseFloat(slider.min);
        const max = parseFloat(slider.max);
        
        // Clamp value to slider range
        if (value >= min && value <= max) {
            slider.value = value;
        }
        
        currentCameraSettings = getCurrentCameraSettings();
        if (isPreviewActive) {
            updatePreview();
        }
    });

    slider.addEventListener('input', function() {
        input.value = this.value;
        currentCameraSettings = getCurrentCameraSettings();
        if (isPreviewActive) {
            updatePreview();
        }
    });
}

// Setup all slider/input syncing
syncInputs('spawnX', 'spawnXSlider');
syncInputs('spawnY', 'spawnYSlider');
syncInputs('spawnZ', 'spawnZSlider');
syncInputs('heading', 'headingSlider');
syncInputs('camOffsetX', 'camOffsetXSlider');
syncInputs('camOffsetY', 'camOffsetYSlider');
syncInputs('camOffsetZ', 'camOffsetZSlider');
syncInputs('camRotX', 'camRotXSlider');
syncInputs('camRotY', 'camRotYSlider');
syncInputs('camRotZ', 'camRotZSlider');
syncInputs('fov', 'fovSlider');

// Collapsible camera section
document.getElementById('cameraHeader').addEventListener('click', function() {
    this.classList.toggle('collapsed');
    document.getElementById('cameraContent').classList.toggle('collapsed');
});

// Preview button
document.getElementById('previewBtn').addEventListener('click', function() {
    isPreviewActive = !isPreviewActive;
    this.classList.toggle('active');
    this.innerHTML = isPreviewActive 
        ? '<span class="btn-icon">⏹</span>STOP PREVIEW' 
        : '<span class="btn-icon">👁</span>PREVIEW';

    if (isPreviewActive) {
        startPreview();
    } else {
        stopPreview();
    }
});

// Reset button
document.getElementById('resetBtn').addEventListener('click', function() {
    currentCameraSettings = JSON.parse(JSON.stringify(originalCameraSettings));
    loadCameraSettings(currentCameraSettings);
    if (isPreviewActive) {
        updatePreview();
    }
    showNotification('Camera settings reset to original values', 'success');
});

// Save to config button
document.getElementById('saveConfigBtn').addEventListener('click', function() {
    const settings = getCurrentCameraSettings();
    
    fetch(`https://vehicle-image-generator/saveConfig`, {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json'
        },
        body: JSON.stringify({ cameraSettings: settings })
    });
});

// Start preview mode
function startPreview() {
    const settings = getCurrentCameraSettings();
    fetch(`https://vehicle-image-generator/startPreview`, {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json'
        },
        body: JSON.stringify({ cameraSettings: settings })
    });
}

// Update preview with new settings
function updatePreview() {
    const settings = getCurrentCameraSettings();
    fetch(`https://vehicle-image-generator/updatePreview`, {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json'
        },
        body: JSON.stringify({ cameraSettings: settings })
    });
}

// Stop preview mode
function stopPreview() {
    fetch(`https://vehicle-image-generator/stopPreview`, {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json'
        },
        body: JSON.stringify({})
    });
}

