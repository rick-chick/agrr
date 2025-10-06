// Fields JavaScript functionality

let map;
let marker;

// Default position (Tokyo Station)
const defaultLat = 35.6812;
const defaultLng = 139.7671;

function initMap() {
  // Get current coordinates from form - support both farm and field forms
  let latElement = document.getElementById('field_latitude');
  let lngElement = document.getElementById('field_longitude');
  
  // If field form elements not found, try farm form elements
  if (!latElement || !lngElement) {
    latElement = document.getElementById('farm_latitude');
    lngElement = document.getElementById('farm_longitude');
  }
  
  // If still not found, try by name attribute
  if (!latElement || !lngElement) {
    latElement = document.querySelector('input[name*="[latitude]"]');
    lngElement = document.querySelector('input[name*="[longitude]"]');
  }
  
  // Check if elements exist before accessing their values
  if (!latElement || !lngElement) {
    console.error('Required form elements not found: latitude or longitude fields');
    return;
  }
  
  // Safely get values with null checks
  const currentLat = latElement ? (parseFloat(latElement.value) || defaultLat) : defaultLat;
  const currentLng = lngElement ? (parseFloat(lngElement.value) || defaultLng) : defaultLng;
  
  // Initialize map
  map = L.map('map').setView([currentLat, currentLng], 13);
  
  // Add tile layer
  L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', {
    attribution: '© OpenStreetMap contributors'
  }).addTo(map);
  
  // Hide placeholder
  const placeholder = document.getElementById('map-placeholder');
  if (placeholder) {
    placeholder.style.display = 'none';
  }
  
  // Add marker at current position
  if (!isNaN(currentLat) && !isNaN(currentLng)) {
    marker = L.marker([currentLat, currentLng]).addTo(map);
  }
  
  // Set initial form values safely
  if (latElement) latElement.value = currentLat;
  if (lngElement) lngElement.value = currentLng;
  
  // Handle map clicks
  map.on('click', function(e) {
    const lat = e.latlng.lat;
    const lng = e.latlng.lng;
    
    // Update marker
    if (marker) {
      map.removeLayer(marker);
    }
    marker = L.marker([lat, lng]).addTo(map);
    
    // Update form values safely
    if (latElement) latElement.value = lat.toFixed(8);
    if (lngElement) lngElement.value = lng.toFixed(8);
  });
  
  // Handle form value changes safely
  if (latElement) latElement.addEventListener('change', updateMarker);
  if (lngElement) lngElement.addEventListener('change', updateMarker);
}

function updateMarker() {
  // Get current coordinates from form - support both farm and field forms
  let latElement = document.getElementById('field_latitude');
  let lngElement = document.getElementById('field_longitude');
  
  // If field form elements not found, try farm form elements
  if (!latElement || !lngElement) {
    latElement = document.getElementById('farm_latitude');
    lngElement = document.getElementById('farm_longitude');
  }
  
  // If still not found, try by name attribute
  if (!latElement || !lngElement) {
    latElement = document.querySelector('input[name*="[latitude]"]');
    lngElement = document.querySelector('input[name*="[longitude]"]');
  }
  
  if (!latElement || !lngElement) {
    console.error('Required form elements not found in updateMarker');
    return;
  }
  
  // Safely get values with null checks
  const lat = latElement ? parseFloat(latElement.value) : NaN;
  const lng = lngElement ? parseFloat(lngElement.value) : NaN;
  
  if (!isNaN(lat) && !isNaN(lng)) {
    if (marker) {
      map.removeLayer(marker);
    }
    marker = L.marker([lat, lng]).addTo(map);
    map.setView([lat, lng], Math.max(map.getZoom(), 15));
  }
}

// Initialize map when page loads
document.addEventListener('DOMContentLoaded', function() {
  // Only initialize if map element exists
  if (document.getElementById('map')) {
    initMap();
  }
});

