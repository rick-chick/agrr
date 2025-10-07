// fields.js - 地図機能とフォーム連携のためのJavaScript

// Leafletの読み込み完了を待つ関数
function waitForLeaflet(callback, maxAttempts = 100) {
  console.log('Waiting for Leaflet, attempts remaining:', maxAttempts);
  
  if (typeof L !== 'undefined' && L.Map) {
    console.log('Leaflet is ready, version:', L.version);
    callback();
    return;
  }
  
  if (maxAttempts <= 0) {
    console.error('Leaflet library failed to load after maximum attempts');
    const errorPlaceholder = document.getElementById('map-placeholder');
    if (errorPlaceholder) {
      errorPlaceholder.innerHTML = '<div>⚠️ 地図の読み込みに失敗しました</div>';
    }
    return;
  }
  
  setTimeout(() => waitForLeaflet(callback, maxAttempts - 1), 100);
}

// Turbo対応: turbo:loadイベントでページ読み込み時とTurbo遷移時の両方で地図を初期化
document.addEventListener('turbo:load', function() {
  // 地図要素が存在する場合のみ初期化
  const mapElement = document.getElementById('map');
  if (!mapElement) {
    return;
  }

  // Leafletの読み込み完了を待つ
  waitForLeaflet(initializeMapComponents);
});

// Turboキャッシュ前に地図をクリーンアップ
document.addEventListener('turbo:before-cache', function() {
  if (map) {
    console.log('Cleaning up map before Turbo cache');
    map.remove();
    map = null;
    marker = null;
    isInitialized = false;
  }
});

// 地図の初期化
let map;
let marker;
let isInitialized = false;

function initializeMapComponents() {
  console.log('Initializing map components...');
  if (isInitialized) {
    console.log('Map already initialized, skipping');
    return;
  }
  
  try {
    console.log('Leaflet version:', L.version);
    console.log('Leaflet available:', typeof L !== 'undefined');
    
    // 既存の地図インスタンスをクリア
    if (map) {
      console.log('Removing existing map instance');
      map.remove();
      map = null;
    }
    
    // 地図コンテナをクリア
    const mapElement = document.getElementById('map');
    if (mapElement) {
      mapElement.innerHTML = '';
    }
    
    // LeafletのアイコンパスをCDNから設定
    console.log('Setting up Leaflet icon paths...');
    delete L.Icon.Default.prototype._getIconUrl;
    L.Icon.Default.mergeOptions({
      iconRetinaUrl: 'https://cdnjs.cloudflare.com/ajax/libs/leaflet/1.9.4/images/marker-icon-2x.png',
      iconUrl: 'https://cdnjs.cloudflare.com/ajax/libs/leaflet/1.9.4/images/marker-icon.png',
      shadowUrl: 'https://cdnjs.cloudflare.com/ajax/libs/leaflet/1.9.4/images/marker-shadow.png',
    });
    console.log('Icon paths configured');
    
    // プレースホルダーを非表示にする
    const placeholder = document.getElementById('map-placeholder');
    if (placeholder) {
      placeholder.style.display = 'none';
    }
    
    // 緯度・経度の入力フィールドを取得
    const latInput = document.getElementById('farm_latitude');
    const lngInput = document.getElementById('farm_longitude');
    
    // デフォルトの座標（東京駅）
    let defaultLat = 35.6812;
    let defaultLng = 139.7671;
    
    // フォームに既存の値がある場合はそれを使用
    if (latInput && latInput.value) {
      defaultLat = parseFloat(latInput.value);
    }
    if (lngInput && lngInput.value) {
      defaultLng = parseFloat(lngInput.value);
    }
    
    // 地図を初期化（より厳密な設定）
    console.log('Initializing map with coordinates:', defaultLat, defaultLng);
    map = L.map('map', {
      center: [defaultLat, defaultLng],
      zoom: 13,
      zoomControl: true,
      attributionControl: true,
      preferCanvas: false,
      renderer: L.svg()
    });
    console.log('Map initialized:', map);
    
    // タイルレイヤーを追加（OpenStreetMap France - 高品質）
    const tileLayer = L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', {
      attribution: '© OpenStreetMap contributors',
      maxZoom: 20,
      tileSize: 256,
      zoomOffset: 0,
      subdomains: 'abc'
    });
    
    // タイルレイヤーの読み込み完了を待つ
    tileLayer.on('tileload', function() {
      console.log('Tile loaded successfully');
    });
    
    tileLayer.on('tileerror', function(error) {
      console.error('Tile loading error:', error);
    });
    
    tileLayer.addTo(map);
    
    // マーカーを追加（日本語ラベル付き）
    console.log('Adding marker at:', defaultLat, defaultLng);
    marker = L.marker([defaultLat, defaultLng], { draggable: true }).addTo(map);
    marker.bindPopup('農場の位置').openPopup();
    console.log('Marker added:', marker);
    
    // マーカーをドラッグした時の処理
    marker.on('dragend', function(e) {
      const position = e.target.getLatLng();
      updateCoordinateInputs(position.lat, position.lng);
    });
    
    // 地図をクリックした時の処理
    map.on('click', function(e) {
      const lat = e.latlng.lat;
      const lng = e.latlng.lng;
      
      // マーカーの位置を更新
      marker.setLatLng([lat, lng]);
      
      // 入力フィールドの値を更新
      updateCoordinateInputs(lat, lng);
    });
    
    // 入力フィールドの値が変更された時の処理
    if (latInput && lngInput) {
      latInput.addEventListener('input', updateMapFromInputs);
      lngInput.addEventListener('input', updateMapFromInputs);
    }
    
    // プレースホルダーを非表示（既に取得済み）
    if (placeholder) {
      placeholder.style.display = 'none';
    }
    
    isInitialized = true;
    
  } catch (error) {
    console.error('Error initializing map:', error);
    // エラー時はプレースホルダーを表示
    const placeholder = document.getElementById('map-placeholder');
    if (placeholder) {
      placeholder.style.display = 'block';
      placeholder.innerHTML = '<div>❌ 地図の読み込みに失敗しました</div>';
    }
  }
}

// 座標入力フィールドの値を更新
function updateCoordinateInputs(lat, lng) {
  const latInput = document.getElementById('farm_latitude');
  const lngInput = document.getElementById('farm_longitude');
  
  if (latInput) {
    latInput.value = lat.toFixed(6);
  }
  if (lngInput) {
    lngInput.value = lng.toFixed(6);
  }
}

// 入力フィールドから地図を更新
function updateMapFromInputs() {
  const latInput = document.getElementById('farm_latitude');
  const lngInput = document.getElementById('farm_longitude');
  
  if (!latInput || !lngInput || !map || !marker) return;
  
  const lat = parseFloat(latInput.value);
  const lng = parseFloat(lngInput.value);
  
  // 有効な座標の場合のみ更新
  if (!isNaN(lat) && !isNaN(lng) && lat >= -90 && lat <= 90 && lng >= -180 && lng <= 180) {
    // マーカーの位置を更新（ドラッグイベントを一時的に無効化）
    marker.off('dragend');
    marker.setLatLng([lat, lng]);
    marker.on('dragend', function(e) {
      const position = e.target.getLatLng();
      updateCoordinateInputs(position.lat, position.lng);
    });
    
    // 地図の中心を更新
    map.setView([lat, lng], map.getZoom());
  }
}

// フォーム送信時のバリデーション
document.addEventListener('submit', function(e) {
  const latInput = document.getElementById('farm_latitude');
  const lngInput = document.getElementById('farm_longitude');
  
  if (latInput && lngInput) {
    const lat = parseFloat(latInput.value);
    const lng = parseFloat(lngInput.value);
    
    if (isNaN(lat) || isNaN(lng)) {
      e.preventDefault();
      alert('緯度と経度は数値で入力してください。');
      return false;
    }
    
    if (lat < -90 || lat > 90) {
      e.preventDefault();
      alert('緯度は-90から90の間で入力してください。');
      return false;
    }
    
    if (lng < -180 || lng > 180) {
      e.preventDefault();
      alert('経度は-180から180の間で入力してください。');
      return false;
    }
  }
});

// ユーティリティ関数
function formatCoordinate(coord, precision = 6) {
  return parseFloat(coord).toFixed(precision);
}

// 座標の妥当性チェック
function isValidCoordinate(lat, lng) {
  return !isNaN(lat) && !isNaN(lng) && 
         lat >= -90 && lat <= 90 && 
         lng >= -180 && lng <= 180;
}