import assert from 'node:assert/strict';
import { mkdtemp, writeFile, mkdir } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join, dirname } from 'node:path';
import { test } from 'node:test';

import { scanBreadcrumbCampaign } from './scan-breadcrumb-campaign.mjs';

test('scanBreadcrumbCampaign: 戻るパターンを検出し issue 候補をグループ化', async () => {
  const repoRoot = await mkdtemp(join(tmpdir(), 'breadcrumb-scan-'));
  const campaignPath = join(repoRoot, 'campaign.json');
  await writeFile(
    campaignPath,
    JSON.stringify({
      id: 'breadcrumb',
      label: 'ux-campaign:breadcrumb',
      title: '戻るボタン廃止・パンくず統一',
      issueTitlePrefix: '[P1][UX]',
      issueTitleSuffix: '戻るボタンを廃止しパンくずに統一',
      referenceLayout: 'frontend/src/app/components/masters/_master-layout.css',
      designNotes: ['パンくずを page-header 直上に置く'],
    }),
  );

  const farmDetail = join(
    repoRoot,
    'frontend/src/app/components/masters/farms/farm-detail.component.ts',
  );
  await mkdir(dirname(farmDetail), { recursive: true });
  await writeFile(
    farmDetail,
    `<a routerLink="/farms">{{ 'farms.show.back_to_list' | translate }}</a>`,
  );

  const farmList = join(
    repoRoot,
    'frontend/src/app/components/masters/farms/farm-list.component.ts',
  );
  await writeFile(farmList, `<header class="page-header"></header>`);

  const result = await scanBreadcrumbCampaign({ repoRoot, campaignPath });

  assert.equal(result.campaignComplete, false);
  assert.equal(result.counts.violationFiles, 1);
  assert.equal(result.issueCandidates.length, 1);
  assert.equal(result.issueCandidates[0].routeGroup, 'masters/farms');
  assert.match(result.issueCandidates[0].suggestedTitle, /masters\/farms/);
});

test('scanBreadcrumbCampaign: 違反なしで campaignComplete', async () => {
  const repoRoot = await mkdtemp(join(tmpdir(), 'breadcrumb-scan-'));
  const campaignPath = join(repoRoot, 'campaign.json');
  await writeFile(
    campaignPath,
    JSON.stringify({
      id: 'breadcrumb',
      label: 'ux-campaign:breadcrumb',
      title: 'test',
      issueTitlePrefix: '[P1][UX]',
      issueTitleSuffix: 'suffix',
      referenceLayout: 'layout.css',
      designNotes: [],
    }),
  );

  const clean = join(
    repoRoot,
    'frontend/src/app/components/masters/fields/field-list.component.ts',
  );
  await mkdir(dirname(clean), { recursive: true });
  await writeFile(
    clean,
    `<nav aria-label="breadcrumb"><ol class="breadcrumb"></ol></nav>`,
  );

  const result = await scanBreadcrumbCampaign({ repoRoot, campaignPath });
  assert.equal(result.campaignComplete, true);
  assert.equal(result.issueCandidates.length, 0);
});
