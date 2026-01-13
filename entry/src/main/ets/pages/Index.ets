/**
 * 主应用入口页面 - 标签页导航控制器
 * 
 * 功能概述：
 * - 提供应用的主要导航结构
 * - 管理四个核心功能页面的切换
 * - 底部标签栏导航设计
 * 
 * 组件结构：
 * - Entry标记为应用入口点
 * - Component定义可复用的UI结构
 * - Tabs组件实现多页面切换
 * 
 * 布局特点：
 * - 底部标签栏位置设计
 * - 四个核心功能模块划分
 * - 简洁的导航交互
 */

// 导入各功能页面组件
import { HomePage } from './HomePage' // 首页文章流
import { CategoryPage } from './CategoryPage' // 分类浏览
import { FavoritePage } from './FavoritePage' // 收藏管理
import { MinePage } from './MinePage' // 个人中心

// 当前主页面Tab索引（默认首页）
AppStorage.setOrCreate('main_tab_index', 0);

/**
 * 主标签页组件
 * 构建应用的根导航结构
 */
@Entry
@Component
struct MainTabs {
  /**
   * 当前选中的标签索引
   * 使用AppStorage同步，便于外部页面切换到指定Tab
   */
  @StorageLink('main_tab_index')
  currentIndex: number = 0;
  /**
   * UI构建方法
   * 创建底部标签栏导航界面
   */
  build() {
    // 底部标签栏配置
    Tabs({ barPosition: BarPosition.End, index: this.currentIndex }) {
      // 首页标签页
      TabContent() {
        HomePage()
      }
      .tabBar({ text: '首页' }) // 首页文章流展示

      // 分类标签页
      TabContent() {
        CategoryPage()
      }
      .tabBar({ text: '分类' }) // 文章分类浏览

      // 收藏标签页
      TabContent() {
        FavoritePage()
      }
      .tabBar({ text: '收藏' }) // 收藏文章管理

      // 我的标签页
      TabContent() {
        MinePage()
      }
      .tabBar({ text: '我的' }) // 个人中心功能
    }
    .onChange((index: number) => {
      this.currentIndex = index;
    })
  }
}