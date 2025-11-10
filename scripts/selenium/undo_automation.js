#!/usr/bin/env node

/**
 * Undo automation scenario runner
 *
 * - Spins up Selenium remote Chrome (assumed running via docker compose service `selenium`)
 * - Seeds deterministic test fixtures via `rails runner`
 * - Executes UI flows for the Undo toast feature across multiple resources
 * - Captures structured logs and screenshots under tmp/selenium
 *
 * Usage:
 *   node scripts/selenium/undo_automation.js
 *
 * Environment variables:
 *   SELENIUM_REMOTE_URL   Remote WebDriver endpoint (default: http://selenium:4444/wd/hub)
 *   APP_BASE_URL          Application base URL (default: http://web:3000)
 *   APP_LOCALE            Locale prefix without leading slash (default: ja)
 *   SELENIUM_OUTPUT_DIR   Root directory for logs/screenshots (default: <pwd>/tmp/selenium)
 */

const fs = require('fs');
const path = require('path');
const { execSync } = require('child_process');
const { Builder, By, Key, until } = require('selenium-webdriver');
const chrome = require('selenium-webdriver/chrome');

const REMOTE_URL = process.env.SELENIUM_REMOTE_URL || 'http://selenium:4444/wd/hub';
const APP_BASE_URL = process.env.APP_BASE_URL || 'http://web:3000';
const APP_LOCALE = process.env.APP_LOCALE || 'ja';
const OUTPUT_ROOT = process.env.SELENIUM_OUTPUT_DIR || path.join(process.cwd(), 'tmp', 'selenium');
const SCREENSHOT_DIR = path.join(OUTPUT_ROOT, 'screenshots');
const LOG_DIR = path.join(OUTPUT_ROOT, 'logs');

ensureDirectories([OUTPUT_ROOT, SCREENSHOT_DIR, LOG_DIR]);

const FARM_NAMES = {
  basic: 'Selenium Farm Timeout 20251110',
  field: 'Selenium Farm 20251110',
  sequentialA: 'Selenium Farm Sequential A 20251110',
  sequentialB: 'Selenium Farm Sequential B 20251110'
};

const context = {
  fieldFarmId: null,
  timeoutFarmId: null,
  sequentialFarmIds: { a: null, b: null }
};

const RESOURCE_TARGETS = [
  {
    key: 'farms',
    name: 'Farms',
    path: () => `/farms`,
    targetName: FARM_NAMES.basic
  },
  {
    key: 'fields',
    name: 'Fields',
    path: () => {
      if (!context.fieldFarmId) throw new Error('Field farm ID is not available');
      return `/farms/${context.fieldFarmId}/fields`;
    },
    targetName: 'Selenium Field 20251110'
  },
  {
    key: 'agricultural_tasks',
    name: 'AgriculturalTasks',
    path: () => `/agricultural_tasks`,
    targetName: 'Selenium Task 20251110'
  },
  {
    key: 'interaction_rules',
    name: 'InteractionRules',
    path: () => `/interaction_rules`,
    targetName: 'Selenium Source'
  },
  {
    key: 'plans',
    name: 'Plans',
    path: () => `/plans`,
    targetName: null // pick first available record
  },
  {
    key: 'crops',
    name: 'Crops',
    path: () => `/crops`,
    targetName: 'Selenium Crop 20251110'
  },
  {
    key: 'fertilizes',
    name: 'Fertilizes',
    path: () => `/fertilizes`,
    targetName: 'Selenium Fertilize 20251110'
  },
  {
    key: 'pesticides',
    name: 'Pesticides',
    path: () => `/pesticides`,
    targetName: 'Selenium Pesticide 20251110'
  },
  {
    key: 'pests',
    name: 'Pests',
    path: () => `/pests`,
    targetName: 'Selenium Pest 20251110'
  }
];

async function main() {
  const logger = createLogger(path.join(LOG_DIR, `undo_automation_${timestamp()}.log`));
  const summary = [];

  logger.info('=== Undo automation run started ===');
  logger.info(`Remote WebDriver: ${REMOTE_URL}`);
  logger.info(`Target app: ${APP_BASE_URL} (locale: ${APP_LOCALE})`);

  seedFixtures(logger);
  const resolvedIds = ensureUndoFarmData(logger, loadContextIds(logger));
  context.fieldFarmId = resolvedIds['field_farm_id'];
  context.timeoutFarmId = resolvedIds['timeout_farm_id'];
  context.sequentialFarmIds = {
    a: resolvedIds['seq_a_farm_id'],
    b: resolvedIds['seq_b_farm_id']
  };

  const driver = await buildDriver();

  try {
    await login(driver, logger);

    // Basic undo validation per resource
    for (const resource of RESOURCE_TARGETS) {
      const result = await runBasicUndoScenario(driver, resource, logger);
      summary.push(result);
    }

    // Additional scenarios on Farms page
    const timeoutResult = await runToastTimeoutScenario(driver, logger);
    summary.push(timeoutResult);

    const sequentialResult = await runSequentialDeletionScenario(driver, logger);
    summary.push(sequentialResult);

    const summaryPath = path.join(LOG_DIR, `undo_automation_summary_${timestamp()}.json`);
    fs.writeFileSync(summaryPath, JSON.stringify(summary, null, 2), 'utf8');
    logger.info(`Summary saved to ${summaryPath}`);

    logger.info('=== Undo automation run finished ===');
  } catch (error) {
    logger.error(`Fatal error: ${error.stack || error.message}`);
    throw error;
  } finally {
    await driver.quit();
  }
}

function seedFixtures(logger) {
  logger.info('Seeding deterministic fixtures for Selenium flow...');
  const rubyScript = `
require 'json'

user = User.find_or_create_by!(google_id: 'dev_user_001') do |u|
  u.email = 'developer@agrr.dev'
  u.name  = '開発者'
  u.avatar_url = 'dev-avatar.svg'
  u.admin = true
end

farm_summary = DeletionUndo::FarmPreparationService.new(user_google_id: 'dev_user_001').call
field_farm = user.farms.find(farm_summary[:field_farm_id])
field = field_farm.fields.find_or_create_by!(name: 'Selenium Field 20251110') do |f|
  f.area = 100
  f.user = user
end

plan_year = Time.zone.today.year
plan = user.cultivation_plans.plan_type_private.find_or_initialize_by(farm: field_farm, plan_year: plan_year)
plan.plan_type = 'private'
plan.plan_name = 'Selenium Plan 20251110'
plan.total_area = field_farm.fields.sum(:area) || 100
plan.status = 'completed'
plan.session_id ||= "selenium-undo-#{plan_year}"
plan.planning_start_date = Date.new(plan_year, 1, 1)
plan.planning_end_date = Date.new(plan_year + 1, 12, 31)
plan.save!

plan.cultivation_plan_fields.destroy_all
plan.cultivation_plan_fields.create!(
  name: field.name,
  area: field.area || 100,
  daily_fixed_cost: 0
)

plan_crop = user.crops.find_or_create_by!(name: 'Selenium Plan Crop 20251110') do |crop_record|
  crop_record.is_reference = false
  crop_record.variety = 'Selenium Plan Variety'
  crop_record.area_per_unit = 0.4
  crop_record.revenue_per_area = 5200
  crop_record.groups = ['selenium-plan']
  crop_record.user = user
end
plan.cultivation_plan_crops.destroy_all
plan.cultivation_plan_crops.create!(
  name: plan_crop.name,
  variety: plan_crop.variety,
  area_per_unit: plan_crop.area_per_unit,
  revenue_per_area: plan_crop.revenue_per_area,
  crop: plan_crop
)

user.agricultural_tasks.find_or_create_by!(name: 'Selenium Task 20251110') do |task|
  task.is_reference = false
  task.description = 'Selenium自動テスト用タスク'
  task.time_per_sqm = 1.5
  task.weather_dependency = 'low'
  task.required_tools = ['selenium']
  task.skill_level = 'beginner'
end

user.interaction_rules.find_or_create_by!(
  rule_type: 'continuous_cultivation',
  source_group: 'Selenium Source',
  target_group: 'Selenium Target'
) do |rule|
  rule.is_reference = false
  rule.impact_ratio = 0.8
  rule.is_directional = true
  rule.description = 'Selenium自動テスト用ルール'
end

user.crops.find_or_create_by!(name: 'Selenium Crop 20251110') do |crop|
  crop.is_reference = false
  crop.variety = 'Selenium Variety'
  crop.area_per_unit = 0.3
  crop.revenue_per_area = 5500
  crop.groups = ['selenium']
end

user.fertilizes.find_or_create_by!(name: 'Selenium Fertilize 20251110') do |fert|
  fert.is_reference = false
  fert.n = 10
  fert.p = 5
  fert.k = 5
  fert.description = 'Selenium自動テスト用肥料'
  fert.package_size = 20
end

user.pests.find_or_create_by!(name: 'Selenium Pest 20251110') do |pest|
  pest.is_reference = false
  pest.name_scientific = 'Selenium pestus'
  pest.family = 'Seleniumidae'
  pest.order = 'Seleniumoptera'
  pest.description = 'Selenium自動テスト用害虫'
  pest.occurrence_season = 'Spring'
end

crop = Crop.first
pest = Pest.first

user.pesticides.find_or_create_by!(name: 'Selenium Pesticide 20251110') do |pesticide|
  pesticide.is_reference = false
  pesticide.crop = crop
  pesticide.pest = pest
  pesticide.active_ingredient = 'Selenium'
  pesticide.description = 'Selenium自動テスト用農薬'
end

field_farm.reload

puts JSON.generate(farm_summary)
  `;
  const useDocker = dockerBinaryAvailable();
  if (useDocker) {
    const command = [
      'docker compose exec web bash -lc',
      JSON.stringify(`rails runner <<'RUBY'\n${rubyScript}\nRUBY`)
    ].join(' ');
    execAndLog(command, logger);
  } else {
    try {
      logger.info('Executing: RAILS_ENV=development bundle exec rails runner - (stdin)');
      execSync('RAILS_ENV=development bundle exec rails runner -', {
        stdio: ['pipe', 'pipe', 'pipe'],
        input: rubyScript
      });
    } catch (error) {
      if (error.stdout) logger.error(`STDOUT: ${error.stdout}`);
      if (error.stderr) logger.error(`STDERR: ${error.stderr}`);
      throw error;
    }
  }
}

function ensureUndoFarmData(logger, ids) {
  const missingKeys = Object.entries(ids).filter(([, value]) => !value).map(([key]) => key);
  if (missingKeys.length === 0) {
    return ids;
  }

  logger.info(`Missing Selenium undo farms for: ${missingKeys.join(', ')}. Running targeted seeding...`);
  seedUndoFarms(logger);

  const refreshedIds = loadContextIds(logger);
  const stillMissing = Object.entries(refreshedIds).filter(([, value]) => !value).map(([key]) => key);
  if (stillMissing.length) {
    throw new Error(`Failed to prepare Selenium undo farms: ${stillMissing.join(', ')}`);
  }

  return refreshedIds;
}

function seedUndoFarms(logger) {
  const rubyScript = `
require 'json'

user = User.find_or_create_by!(google_id: 'dev_user_001') do |u|
  u.email = 'developer@agrr.dev'
  u.name  = '開発者'
  u.avatar_url = 'dev-avatar.svg'
  u.admin = true
end

result = DeletionUndo::FarmPreparationService.new(user_google_id: 'dev_user_001').call
puts JSON.generate(result)
  `;

  const useDocker = dockerBinaryAvailable();
  if (useDocker) {
    const command = [
      'docker compose exec web bash -lc',
      JSON.stringify(`rails runner <<'RUBY'\n${rubyScript}\nRUBY`)
    ].join(' ');
    execAndLog(command, logger);
  } else {
    try {
      logger.info('Ensuring Selenium farms exist for undo scenarios (RAILS_ENV=development bundle exec rails runner)');
      execSync('RAILS_ENV=development bundle exec rails runner -', {
        stdio: ['pipe', 'pipe', 'pipe'],
        input: rubyScript
      });
    } catch (error) {
      logger.error(`Failed to seed Selenium farms: ${error.message}`);
      if (error.stdout) logger.error(`STDOUT: ${error.stdout}`);
      if (error.stderr) logger.error(`STDERR: ${error.stderr}`);
      throw error;
    }
  }
}

async function buildDriver() {
  const options = new chrome.Options();
  options.addArguments(
    '--headless=new',
    '--disable-gpu',
    '--no-sandbox',
    '--disable-dev-shm-usage',
    '--window-size=1600,900'
  );

  return await new Builder()
    .forBrowser('chrome')
    .setChromeOptions(options)
    .usingServer(REMOTE_URL)
    .build();
}

async function login(driver, logger) {
  const loginUrl = `${APP_BASE_URL}/auth/test/mock_login?locale=${APP_LOCALE}`;
  logger.info(`Visiting mock login endpoint: ${loginUrl}`);
  await driver.get(loginUrl);
  await driver.wait(async () => {
    const url = await driver.getCurrentUrl();
    return url.includes(`/${APP_LOCALE}`);
  }, 5000).catch(() => {});

  await driver.get(buildUrl('/'));
  await driver.wait(async () => {
    const url = await driver.getCurrentUrl();
    return url.includes(`/${APP_LOCALE}`);
  }, 5000).catch(() => {});

  await driver.sleep(500);
  const currentUrl = await driver.getCurrentUrl();
  logger.info(`Logged in, current URL: ${currentUrl}`);
}

async function runBasicUndoScenario(driver, resource, logger) {
  const scenarioName = `${resource.name} - 基本Undo`;
  const result = createResult(resource.name, '基本Undo');
  const screenshotLabel = `${resource.key}-basic`;

  try {
    const pageUrl = buildUrl(resource.path());
    logger.info(`[${scenarioName}] Navigating to ${pageUrl}`);
    await driver.get(pageUrl);
    await driver.wait(until.elementLocated(By.css('[data-undo-delete-record]')), 10000);
    await driver.sleep(500);

    const { record, recordId } = await locateRecord(driver, resource.targetName);
    if (!record) throw new Error(`Record with target text "${resource.targetName}" not found`);

    await scrollIntoView(driver, record);
    const deleteButton = await record.findElement(By.css('[data-controller="undo-delete"]'));
    await driver.wait(until.elementIsVisible(deleteButton), 5000);
    await clickElement(driver, deleteButton);

    const toast = await waitForToastVisible(driver);
    await waitForRecordHidden(driver, recordId);

    const undoButton = await driver.findElement(By.css('.undo-toast__undo-button'));
    await driver.executeScript('arguments[0].click();', undoButton);

    await waitForRecordVisible(driver, recordId);
    await waitForToastHidden(driver, toast);

    const screenshotPath = await takeScreenshot(driver, `${screenshotLabel}-success.png`);
    result.status = 'success';
    result.screenshot = screenshotPath;
    result.notes = `Record ${recordId} restored successfully`;
    result.recordId = recordId;

    if (resource.afterSuccess) {
      await resource.afterSuccess({ recordId });
    }

    logger.info(`[${scenarioName}] ✅ Success`);
  } catch (error) {
    const screenshotPath = await takeScreenshot(driver, `${screenshotLabel}-failure.png`);
    result.status = 'failure';
    result.screenshot = screenshotPath;
    result.error = error.message;
    result.pageSource = await savePageSource(driver, `${resource.key}-basic-error.html`).catch(() => null);
    logger.error(`[${scenarioName}] ❌ ${error.message}`);
  }

  return result;
}

async function runToastTimeoutScenario(driver, logger) {
  const scenarioName = 'Farms - トーストタイムアウト';
  const result = createResult('Farms', 'トーストタイムアウト');
  const screenshotLabel = 'farms-timeout';
  const pageUrl = buildUrl('/farms');

  try {
    logger.info(`[${scenarioName}] Navigating to ${pageUrl}`);
    await driver.get(pageUrl);
    await driver.wait(until.elementLocated(By.css('[data-undo-delete-record]')), 10000);
    await driver.sleep(500);

    const { record, recordId } = await locateRecord(driver, 'Selenium Farm Timeout 20251110');
    if (!record) throw new Error('Timeout farm record not found');

    await scrollIntoView(driver, record);
    await clickElement(driver, await record.findElement(By.css('[data-controller="undo-delete"]')));

    const toast = await waitForToastVisible(driver);
    await waitForRecordHidden(driver, recordId);

    logger.info(`[${scenarioName}] Waiting for auto hide...`);
    await driver.sleep(6500); // allow auto-hide to trigger (default 5000ms)
    await waitForToastHidden(driver, toast, { timeoutMs: 3000 });

    const classes = await getElementClasses(driver, recordId);
    if (!classes.includes('undo-delete--hidden')) {
      throw new Error('Record is not hidden after toast timeout');
    }

    const screenshotPath = await takeScreenshot(driver, `${screenshotLabel}-success.png`);
    result.status = 'success';
    result.screenshot = screenshotPath;
    result.notes = `Record ${recordId} remained hidden after timeout`;
    logger.info(`[${scenarioName}] ✅ Success`);
  } catch (error) {
    const screenshotPath = await takeScreenshot(driver, `${screenshotLabel}-failure.png`);
    result.status = 'failure';
    result.screenshot = screenshotPath;
    result.error = error.message;
    result.pageSource = await savePageSource(driver, `${scenarioName.replace(/\s+/g, '-')}-error.html`).catch(() => null);
    logger.error(`[${scenarioName}] ❌ ${error.message}`);
  }

  return result;
}

async function runSequentialDeletionScenario(driver, logger) {
  const scenarioName = 'Farms - 連続削除Undo';
  const result = createResult('Farms', '連続削除→Undo');
  const screenshotLabel = 'farms-sequential';
  const pageUrl = buildUrl('/farms');

  try {
    logger.info(`[${scenarioName}] Navigating to ${pageUrl}`);
    await driver.get(pageUrl);
    await driver.wait(until.elementLocated(By.css('[data-undo-delete-record]')), 10000);
    await driver.sleep(500);

    const recordAData = await locateRecord(driver, 'Selenium Farm Sequential A 20251110');
    const recordBData = await locateRecord(driver, 'Selenium Farm Sequential B 20251110');
    if (!recordAData.record || !recordBData.record) {
      throw new Error('Sequential farm records not found');
    }

    await scrollIntoView(driver, recordAData.record);
    await clickElement(driver, await recordAData.record.findElement(By.css('[data-controller="undo-delete"]')));
    await waitForToastVisible(driver);
    await waitForRecordHidden(driver, recordAData.recordId);

    await scrollIntoView(driver, recordBData.record);
    await clickElement(driver, await recordBData.record.findElement(By.css('[data-controller="undo-delete"]')));
    const toast = await waitForToastVisible(driver);
    await waitForRecordHidden(driver, recordBData.recordId);

    const undoButton = await driver.findElement(By.css('.undo-toast__undo-button'));
    await driver.executeScript('arguments[0].click();', undoButton);

    await waitForRecordVisible(driver, recordBData.recordId);
    await waitForToastHidden(driver, toast);

    const classesA = await getElementClasses(driver, recordAData.recordId).catch(() => '');
    const classesB = await getElementClasses(driver, recordBData.recordId);

    result.status = 'success';
    result.notes = [
      `Record B ${recordBData.recordId} restored after undo`,
      classesA.includes('undo-delete--hidden')
        ? `Record A ${recordAData.recordId} remains hidden (expected without additional undo)`
        : `Record A ${recordAData.recordId} visible`
    ].join(' / ');

    result.screenshot = await takeScreenshot(driver, `${screenshotLabel}-success.png`);
    logger.info(`[${scenarioName}] ✅ Success`);
  } catch (error) {
    const screenshotPath = await takeScreenshot(driver, `${screenshotLabel}-failure.png`);
    result.status = 'failure';
    result.screenshot = screenshotPath;
    result.error = error.message;
    result.pageSource = await savePageSource(driver, `${scenarioName.replace(/\s+/g, '-')}-error.html`).catch(() => null);
    logger.error(`[${scenarioName}] ❌ ${error.message}`);
  }

  return result;
}

function buildUrl(pathname) {
  const normalized = pathname.startsWith('/') ? pathname : `/${pathname}`;
  return `${APP_BASE_URL}/${APP_LOCALE}${normalized}`.replace(/\/{2,}/g, '/').replace('http:/', 'http://').replace('https:/', 'https://');
}

async function locateRecord(driver, targetText) {
  await expandAllDetailsSections(driver);
  const candidates = await driver.findElements(By.css('[data-undo-delete-record]'));
  for (const element of candidates) {
    const text = await element.getText();
    if (!targetText || text.includes(targetText)) {
      const recordId = await element.getAttribute('id');
      return { record: element, recordId };
    }
  }
  return { record: null, recordId: null };
}

async function expandAllDetailsSections(driver) {
  const detailsElements = await driver.findElements(By.css('details'));
  for (const detailsElement of detailsElements) {
    await openDetailsElement(driver, detailsElement);
  }
}

async function openDetailsElement(driver, detailsElement) {
  try {
    const isOpen = await detailsElement.getAttribute('open');
    if (isOpen !== null) return;

    const summary = await detailsElement.findElement(By.css(':scope > summary'));
    await driver.executeScript('arguments[0].scrollIntoView({ block: "center" });', summary);
    await driver.wait(until.elementIsVisible(summary), 1500).catch(() => {});
    await driver.executeScript('arguments[0].click();', summary);
    await driver.wait(async () => {
      try {
        return (await detailsElement.getAttribute('open')) !== null;
      } catch (error) {
        if ((error.name || '').includes('StaleElementReference')) return true;
        return false;
      }
    }, 2000).catch(async () => {
      await driver.executeScript('arguments[0].click();', summary);
      return driver.wait(async () => {
        try {
          return (await detailsElement.getAttribute('open')) !== null;
        } catch (error) {
          if ((error.name || '').includes('StaleElementReference')) return true;
          return false;
        }
      }, 1500).catch(() => false);
    });
  } catch (error) {
    await driver.executeScript(`
      if (!arguments[0].hasAttribute('open')) {
        arguments[0].setAttribute('open', 'open');
      }
    `, detailsElement);
  }
}

async function scrollIntoView(driver, element) {
  await driver.executeScript('arguments[0].scrollIntoView({ block: "center" });', element);
  await driver.sleep(250);
}

async function clickElement(driver, element) {
  await driver.executeScript('arguments[0].click();', element);
  await driver.sleep(100);
}

async function waitForToastVisible(driver, timeoutMs = 5000) {
  const toast = await driver.findElement(By.css('.undo-toast'));
  await driver.wait(async () => {
    const classes = await toast.getAttribute('class');
    return classes && !classes.includes('hidden');
  }, timeoutMs, 'Toast did not become visible');
  await driver.sleep(200);
  return toast;
}

async function waitForToastHidden(driver, toast, options = {}) {
  const timeoutMs = options.timeoutMs || 5000;
  await driver.wait(async () => {
    const classes = await toast.getAttribute('class');
    return classes && classes.includes('hidden');
  }, timeoutMs, 'Toast did not hide');
  await driver.sleep(200);
}

async function waitForRecordHidden(driver, recordId, timeoutMs = 5000) {
  await driver.wait(async () => {
    try {
      const element = await driver.findElement(By.id(recordId));
      const classes = await element.getAttribute('class');
      return classes && classes.includes('undo-delete--hidden');
    } catch (error) {
      const name = (error && error.name) || '';
      if (name.includes('NoSuchElement') || name.includes('StaleElementReference')) {
        return true;
      }
      return false;
    }
  }, timeoutMs, `Record ${recordId} did not gain hidden class`);
  await driver.sleep(200);
}

async function waitForRecordVisible(driver, recordId, timeoutMs = 5000) {
  await driver.wait(async () => {
    try {
      const element = await driver.findElement(By.id(recordId));
      const classes = await element.getAttribute('class');
      const displayed = await element.isDisplayed().catch(() => false);
      return displayed && (!classes || !classes.includes('undo-delete--hidden'));
    } catch (error) {
      return false;
    }
  }, timeoutMs, `Record ${recordId} did not remove hidden class`);
  await ensureDetailsOpenForRecord(driver, recordId);
  await driver.sleep(200);
}

async function ensureDetailsOpenForRecord(driver, recordId) {
  try {
    const element = await driver.findElement(By.id(recordId));
    await driver.executeScript(`
      const target = arguments[0];
      let node = target;
      while (node && node.parentElement) {
        if (node.tagName && node.tagName.toLowerCase() === 'details' && !node.hasAttribute('open')) {
          const summary = node.querySelector(':scope > summary');
          if (summary) {
            summary.click();
          }
          node.setAttribute('open', 'open');
        }
        node = node.parentElement;
      }
    `, element);
    await driver.sleep(150);
  } catch (error) {
    // Element might no longer exist; ignore
  }
}

async function getElementClasses(driver, recordId) {
  const element = await driver.findElement(By.id(recordId));
  const classes = await element.getAttribute('class');
  return classes || '';
}

async function takeScreenshot(driver, fileName) {
  const filePath = path.join(SCREENSHOT_DIR, `${timestamp()}_${fileName}`);
  const image = await driver.takeScreenshot();
  fs.writeFileSync(filePath, image, 'base64');
  return filePath;
}

function ensureDirectories(dirs) {
  dirs.forEach((dir) => {
    if (!fs.existsSync(dir)) {
      fs.mkdirSync(dir, { recursive: true });
    }
  });
}

function createLogger(filePath) {
  return {
    info(message) {
      logToFile(filePath, 'INFO', message);
    },
    error(message) {
      logToFile(filePath, 'ERROR', message);
    }
  };
}

function logToFile(filePath, level, message) {
  const line = `[${new Date().toISOString()}] [${level}] ${message}`;
  console.log(line);
  fs.appendFileSync(filePath, `${line}\n`, 'utf8');
}

function execAndLog(command, logger) {
  try {
    logger.info(`Executing: ${command}`);
    const output = execSync(command, { stdio: 'pipe', encoding: 'utf8' });
    if (output.trim().length > 0) {
      logger.info(`Command output:\n${output.trim()}`);
    }
  } catch (error) {
    logger.error(`Command failed: ${error.message}`);
    if (error.stdout) logger.error(`STDOUT: ${error.stdout}`);
    if (error.stderr) logger.error(`STDERR: ${error.stderr}`);
    throw error;
  }
}

function createResult(resource, scenario) {
  return {
    resource,
    scenario,
    status: 'pending',
    screenshot: null,
    notes: null,
    error: null,
    pageSource: null
  };
}

function timestamp() {
  return new Date().toISOString().replace(/[:.]/g, '-');
}

function dockerBinaryAvailable() {
  if (process.env.FORCE_DOCKER === '0') return false;
  try {
    execSync('docker compose version', { stdio: 'pipe' });
    return true;
  } catch {
    return false;
  }
}

async function savePageSource(driver, fileName) {
  const html = await driver.getPageSource();
  const safeName = safeFileName(fileName);
  const filePath = path.join(LOG_DIR, `${timestamp()}_${safeName}`);
  fs.writeFileSync(filePath, html, 'utf8');
  return filePath;
}

function safeFileName(name) {
  return name.replace(/[^\w.-]+/g, '_');
}

function loadContextIds(logger) {
  const rubyScript = `
require 'json'
user = User.find_by!(google_id: 'dev_user_001')
data = {
  field_farm_id: user.farms.find_by(name: '${FARM_NAMES.field}')&.id,
  timeout_farm_id: user.farms.find_by(name: '${FARM_NAMES.basic}')&.id,
  seq_a_farm_id: user.farms.find_by(name: '${FARM_NAMES.sequentialA}')&.id,
  seq_b_farm_id: user.farms.find_by(name: '${FARM_NAMES.sequentialB}')&.id
}
puts data.to_json
  `;

  try {
    const output = execSync('RAILS_ENV=development bundle exec rails runner -', {
      stdio: ['pipe', 'pipe', 'pipe'],
      input: rubyScript
    }).toString().trim();
    logger.info(`Resolved farm context IDs: ${output}`);
    return JSON.parse(output);
  } catch (error) {
    logger.error(`Failed to resolve farm IDs: ${error.message}`);
    return {
      field_farm_id: null,
      timeout_farm_id: null,
      seq_a_farm_id: null,
      seq_b_farm_id: null
    };
  }
}

main().catch((error) => {
  console.error('Automation run failed:', error);
  process.exitCode = 1;
});

