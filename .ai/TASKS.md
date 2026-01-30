# Project Tasks

Rails HTML Clean Architecture 化の未完了対応（RAILS_HTML_CLEAN_ARCH_REMAINING.md に基づく）。

- [x] **ID 1: FertilizesController の index/show を Interactor + HTML Presenter に移行** (Priority: medium)
> FertilizesController の index を FertilizeListInteractor + FertilizeListHtmlPresenter、show を FertilizeDetailInteractor + FertilizeDetailHtmlPresenter に寄せ、既存の Policy 直接呼び出しをやめる。

- [x] **ID 2: AgriculturalTasksController の index を ListInteractor に寄せるか検討・実装** (Priority: low)
> AgriculturalTasksController の index は現状 ActiveRecord と Policy の scope を直接使用している。現状のフィルタ・スコープを維持しつつ、ListInteractor + Presenter に寄せるか検討し、妥当であれば実装する。

- [x] **ID 3: PestsController の create/update を pest_params と rescue で統一** (Priority: medium)
> PestsController の create/update で DTO を pest_params から組み立て、失敗時に rescue StandardError で render :new / :edit と flash.now[:alert] を設定する。

- [x] **ID 4: InteractionRulesController の create/update の rescue でエラーメッセージを表示** (Priority: low)
> InteractionRulesController の create/update で rescue StandardError 時に flash.now[:alert] = e.message を設定し、ユーザーにエラー内容が表示されるようにする。
