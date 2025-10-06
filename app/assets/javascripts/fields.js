// Fields JavaScript functionality

let map;
let marker;

// Default position (Tokyo Station)
const defaultLat = 35.6812;
const defaultLng = 139.7671;

function initMap() {
  // Get current coordinates from form (for edit page) or use default
  const latElement = document.getElementById('field_latitude');
  const lngElement = document.getElementById('field_longitude');
  
  // Check if elements exist before accessing their values
  if (!latElement || !lngElement) {
    console.error('Required form elements not found: field_latitude or field_longitude');
    console.log('Available elements with "field" in ID:', 
      Array.from(document.querySelectorAll('[id*="field"]')).map(el => el.id));
    return;
  }
  
  const currentLat = parseFloat(latElement.value) || defaultLat;
  const currentLng = parseFloat(lngElement.value) || defaultLng;
  
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
  
  // Set initial form values
  latElement.value = currentLat;
  lngElement.value = currentLng;
  
  // Handle map clicks
  map.on('click', function(e) {
    const lat = e.latlng.lat;
    const lng = e.latlng.lng;
    
    // Update marker
    if (marker) {
      map.removeLayer(marker);
    }
    marker = L.marker([lat, lng]).addTo(map);
    
    // Update form values
    latElement.value = lat.toFixed(8);
    lngElement.value = lng.toFixed(8);
  });
  
  // Handle form value changes
  latElement.addEventListener('change', updateMarker);
  lngElement.addEventListener('change', updateMarker);
}

function updateMarker() {
  const latElement = document.getElementById('field_latitude');
  const lngElement = document.getElementById('field_longitude');
  
  if (!latElement || !lngElement) {
    console.error('Required form elements not found in updateMarker');
    return;
  }
  
  const lat = parseFloat(latElement.value);
  const lng = parseFloat(lngElement.value);
  
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

