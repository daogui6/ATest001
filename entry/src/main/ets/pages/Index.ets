import { HomePage } from './HomePage'
import { CategoryPage } from './CategoryPage'
import { FavoritePage } from './FavoritePage'
import { MinePage } from './MinePage'

@Entry
@Component
struct MainTabs {
  build() {
    Tabs({ barPosition: BarPosition.End }) {
      TabContent() {
        HomePage()
      }
      .tabBar({ text: '首页' })

      TabContent() {
        CategoryPage()
      }
      .tabBar({ text: '分类' })

      TabContent() {
        FavoritePage()
      }
      .tabBar({ text: '收藏' })

      TabContent() {
        MinePage()
      }
      .tabBar({ text: '我的' })
    }
  }
}
