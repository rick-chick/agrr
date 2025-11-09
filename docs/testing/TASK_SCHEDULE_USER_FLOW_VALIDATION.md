# タイムライン改善のユーザ動作確認手順

最新の TaskSchedule 改善状況をユーザ視点で再現・検証するためのフローをまとめます。  
以下の手順を通しで実施することで、公開計画の再生成からユーザUIでの確認までを追跡できます。

---

## 事前準備
- Docker 環境で `web` コンテナと `test` コンテナが利用できること。
- モックログイン機能 (`/auth/test/mock_login`) が有効であること。

---

## フロー A: 公開計画の再生成
1. **既存のスケジュールをリセット**
   ```bash
   docker compose exec web bundle exec rails runner "
     plan = CultivationPlan.find(19);
     TaskScheduleItem.joins(:task_schedule)
       .where(task_schedules: { cultivation_plan: plan }).delete_all;
     TaskSchedule.where(cultivation_plan: plan).delete_all
   "
   ```
2. **TaskScheduleGeneratorService を再実行**
   ```bash
   docker compose exec web bundle exec rails runner "
     TaskScheduleGeneratorService.new.generate!(cultivation_plan_id: 19)
   "
   ```
3. **生成結果の確認（任意）**  
   ```bash
   docker compose exec web bundle exec rails runner "
     plan = CultivationPlan.find(19);
     plan.task_schedules.includes(:task_schedule_items).each do |schedule|
       puts({ category: schedule.category,
              dates: schedule.task_schedule_items.order(:scheduled_date).pluck(:scheduled_date).uniq })
     end
   "
   ```
   → `灌水` が開始日以降（例: 2026-04-04）、`収穫` が 4 月下旬などに分散していることを確認。

---

## フロー B: PlanSaveService でユーザー計画へコピー
4. **既存のコピー計画を削除（任意）**
   ```bash
   docker compose exec web bundle exec rails runner "
     if (plan = CultivationPlan.find_by(id: 25)); plan.destroy; end
   "
   ```
5. **PlanSaveService の実行**
   ```bash
   docker compose exec web bundle exec rails runner "
     user = User.find_by!(google_id: 'dev_user_001');
     plan = CultivationPlan.find(19);
     field_data = plan.cultivation_plan_fields.map { |field| { name: field.name, area: field.area } };
     crop_ids = plan.cultivation_plan_crops.map { |cpc| cpc.crop.source_crop_id || cpc.crop_id };
     session_data = { plan_id: plan.id, farm_id: plan.farm_id, crop_ids: crop_ids, field_data: field_data };
     result = PlanSaveService.new(user: user, session_data: session_data).call;
     puts result.inspect
   "
   ```
   → `new_plan_id` が返ることを確認（例: `25`）。  

6. **コピー先の DB 状態を確認（任意）**
   ```bash
   docker compose exec web bundle exec rails runner "
     plan = CultivationPlan.find(25);
     plan.task_schedules.includes(:task_schedule_items).each do |schedule|
       puts({ category: schedule.category,
              dates: schedule.task_schedule_items.order(:scheduled_date).pluck(:scheduled_date).uniq })
     end
   "
   ```
   → 公開側と同様に日付が複数週に分散していることを確認。

---

## フロー C: ユーザー UI での確認
7. **モックログイン**
   ```bash
   curl -s -L -c /tmp/agrr_dev_cookies.txt \
     "http://localhost:3000/auth/test/mock_login"
   ```
8. **コピー済み計画を表示**  
   `http://localhost:3000/ja/plans` → `山形の計画 (2025)` を確認。
9. **「詳細を見る」→「作業予定を見る」**
   - `http://localhost:3000/ja/plans/25/task_schedule` にアクセス。
   - 初期表示では最初の週が選択され、開始日のタスクが並ぶ点に注意。
10. **週送りまたは JSON の直接確認**
    - 週送りボタンでウィークを進める、または以下のようなリクエストで後続週の JSON を取得。
      ```bash
      curl -s -L -b /tmp/agrr_dev_cookies.txt \
        "http://localhost:3000/ja/plans/25/task_schedule.json?week_start=2026-04-06" | jq '.fields[0].schedules'
      ```
    - 例: `2026-04-11` に追肥、`2026-04-27` に収穫関連が表示されれば OK。

---

## 注意点・補足
- 初期週に作業が集中して見えるのは仕様（最初の週だけを表示）なので、後続週を確認して判断する。
- ミニマップで濃い週があれば、クリックしてジャンプ可能。
- 実際のユーザー体験を重視する場合、ブラウザのツールで network / JSON を直接確認する、もしくはスクリーンショットを取るとわかりやすい。

---

## 参考
- 修正内容: `app/services/task_schedule_generator_service.rb`（開始日以降で天気データをフィルタ）
- テスト: `test/services/task_schedule_generator_service_test.rb`

以上の手順で、誰でも公開→コピー→UI の流れを再現できます。*** End Patch

