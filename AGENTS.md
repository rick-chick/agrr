# Project rules
## 変更がないのにテストを２度走らせない
- OK
1. cd /home/akishige/projects/agrr && .cursor/skills/test-common/scripts/run-test-rails.sh [file|..] > ./tmp/{UUID}.log
2. grep|tail|head|... ./tmp/{UUID}.log
- NG
1. cd /home/akishige/projects/agrr && .cursor/skills/test-common/scripts/run-test-rails.sh [file|..] > 2>&1 | tails -20
2. cd /home/akishige/projects/agrr && .cursor/skills/test-common/scripts/run-test-rails.sh [file|..] > 2>&1 | grep hoge

## Readツールの使用はレンジを絞ること
- OK
1. まず grep で該当箇所を特定 → 行番号を把握
2. read で offset/limit を指定して範囲限定で読み込み
- NG
1. 範囲指定なしで read ツールの使用
