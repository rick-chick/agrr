// fields.js - 地図機能とフォーム連携のためのJavaScript

document.addEventListener('DOMContentLoaded', function() {
  // 地図要素が存在する場合のみ初期化
  const mapElement = document.getElementById('map');
  if (!mapElement) {
    return;
  }

  // Leafletが読み込まれているかチェック
  if (typeof L === 'undefined') {
    console.warn('Leaflet library is not loaded');
    return;
  }

  // 地図の初期化
  let map;
  let marker;
  let isInitialized = false;

  function initializeMap() {
    if (isInitialized) return;
    
    try {
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
      
      // 地図を初期化
      map = L.map('map').setView([defaultLat, defaultLng], 13);
      
      // タイルレイヤーを追加（OpenStreetMap）
      L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', {
        attribution: '© OpenStreetMap contributors'
      }).addTo(map);
      
      // マーカーを追加
      marker = L.marker([defaultLat, defaultLng], { draggable: true }).addTo(map);
      
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
      
      // プレースホルダーを非表示
      const placeholder = document.getElementById('map-placeholder');
      if (placeholder) {
        placeholder.style.display = 'none';
      }
      
      isInitialized = true;
      
    } catch (error) {
      console.error('Error initializing map:', error);
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
  
  // 地図の初期化を実行
  initializeMap();
  
  // Leafletの読み込みが遅延した場合の対応
  if (typeof L === 'undefined') {
    // Leafletの読み込みを待つ
    const checkLeaflet = setInterval(function() {
      if (typeof L !== 'undefined') {
        clearInterval(checkLeaflet);
        initializeMap();
      }
    }, 100);
    
    // 10秒後にタイムアウト
    setTimeout(function() {
      clearInterval(checkLeaflet);
      if (!isInitialized) {
        console.error('Leaflet library failed to load');
        const placeholder = document.getElementById('map-placeholder');
        if (placeholder) {
          placeholder.innerHTML = '<div>⚠️ 地図の読み込みに失敗しました</div>';
        }
      }
    }, 10000);
  }
});

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
