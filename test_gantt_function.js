// Test script for shouldHaveGanttChart function
// This is a simple test to verify the function works correctly

// Mock window.location for testing
global.window = {
  location: {
    pathname: '/',
    hash: '#/public-plans/results?planId=1',
    href: 'http://localhost:3000/#/public-plans/results?planId=1'
  },
  ClientLogger: {
    warn: console.log,
    info: console.log
  }
};

// Copy the function from the file
function shouldHaveGanttChart() {
  const currentPath = window.location.pathname;
  const currentHash = window.location.hash;
  const currentHref = window.location.href;
  console.log('🔍 [Gantt Chart] ページ判定中:', currentPath, 'ハッシュ:', currentHash, 'フルURL:', currentHref);

  // ガントチャートが表示されるページのパターン
  const ganttPages = [
    '/plans/',  // 計画詳細ページ
    '/public_plans/',  // 公開計画詳細ページ
    '/results/'  // 結果ページ
  ];

  // パスまたはハッシュ部分をチェック（Angular SPAのハッシュルーティング対応）
  const hashPath = currentHash ? currentHash.replace('#', '') : '';
  const pathToCheck = hashPath || currentPath;

  // より詳細なパターンマッチング
  const shouldHave = ganttPages.some(pattern => pathToCheck.includes(pattern)) ||
                    currentPath === '/public_plans/results' ||
                    pathToCheck.match(/\/public_plans\/\d+/) ||
                    pathToCheck.match(/\/plans\/\d+/) ||
                    currentHash.includes('/public-plans/results');

  console.log('🔍 [Gantt Chart] ページ判定結果:', shouldHave, 'チェック対象パス:', pathToCheck, 'パターン:', ganttPages);

  // 追加デバッグ: public_plansの場合の詳細ログ
  if (pathToCheck.includes('/public_plans/') || currentHash.includes('/public-plans/')) {
    console.log('📋 [Gantt Chart] Public plansページを検出:', pathToCheck, 'ハッシュ:', currentHash);
  }

  return shouldHave;
}

// Test cases
console.log('=== Testing shouldHaveGanttChart function ===');

// Test 1: Angular SPA hash route (should return true)
console.log('\nTest 1: Angular SPA hash route #/public-plans/results?planId=1');
global.window.location = {
  pathname: '/',
  hash: '#/public-plans/results?planId=1',
  href: 'http://localhost:3000/#/public-plans/results?planId=1'
};
const result1 = shouldHaveGanttChart();
console.log('Result:', result1, '(should be true)');

// Test 2: Regular path route (should return true)
console.log('\nTest 2: Regular path route /public_plans/results');
global.window.location = {
  pathname: '/public_plans/results',
  hash: '',
  href: 'http://localhost:3000/public_plans/results'
};
const result2 = shouldHaveGanttChart();
console.log('Result:', result2, '(should be true)');

// Test 3: Non-gantt page (should return false)
console.log('\nTest 3: Non-gantt page /farms');
global.window.location = {
  pathname: '/farms',
  hash: '',
  href: 'http://localhost:3000/farms'
};
const result3 = shouldHaveGanttChart();
console.log('Result:', result3, '(should be false)');

// Test 4: Angular SPA plans route (should return true)
console.log('\nTest 4: Angular SPA plans route #/plans/123');
global.window.location = {
  pathname: '/',
  hash: '#/plans/123',
  href: 'http://localhost:3000/#/plans/123'
};
const result4 = shouldHaveGanttChart();
console.log('Result:', result4, '(should be true)');

console.log('\n=== Test completed ===');