let vehicleCategories = [];
let isCapturing = false;
let selectedVehicles = [];

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
    
    fetch(`https://vehicle-image-generator/startCapture`, {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json'
        },
        body: JSON.stringify({
            webhook: webhook,
            vehicles: selectedVehicles
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
