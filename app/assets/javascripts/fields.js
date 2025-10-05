// Fields JavaScript functionality

let map;
let marker;

// Default position (Tokyo Station)
const defaultLat = 35.6812;
const defaultLng = 139.7671;

function initMap() {
  // Get current coordinates from form (for edit page) or use default
  const currentLat = parseFloat(document.getElementById('field_latitude').value) || defaultLat;
  const currentLng = parseFloat(document.getElementById('field_longitude').value) || defaultLng;
  
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
  document.getElementById('field_latitude').value = currentLat;
  document.getElementById('field_longitude').value = currentLng;
  
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
    document.getElementById('field_latitude').value = lat.toFixed(8);
    document.getElementById('field_longitude').value = lng.toFixed(8);
  });
  
  // Handle form value changes
  document.getElementById('field_latitude').addEventListener('change', updateMarker);
  document.getElementById('field_longitude').addEventListener('change', updateMarker);
}

function updateMarker() {
  const lat = parseFloat(document.getElementById('field_latitude').value);
  const lng = parseFloat(document.getElementById('field_longitude').value);
  
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

