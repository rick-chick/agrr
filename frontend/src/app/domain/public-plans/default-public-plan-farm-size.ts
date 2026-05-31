import { FarmSizeOption } from './farm-size-option';

/** 公開プラン wizard で農場サイズ選択を省略するときの固定値（300㎡）。API の farm_size_id として "300" を送る。 */
export const DEFAULT_PUBLIC_PLAN_FARM_SIZE: FarmSizeOption = {
  id: '300',
  area_sqm: 300,
  name: '300㎡',
  description: ''
};
