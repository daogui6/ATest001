/*
 * EntryAbility.ets - 应用入口Ability
 * 
 * 功能说明：
 * - 应用的主要入口点，负责应用的生命周期管理
 * - 处理应用启动、前台/后台切换、窗口创建销毁等事件
 * - 设置应用的颜色模式和窗口配置
 * - 加载和显示应用的主页面
 * 
 * 生命周期方法：
 * - onCreate: Ability创建时调用，进行初始化
 * - onDestroy: Ability销毁时调用，清理资源
 * - onWindowStageCreate: 窗口阶段创建，加载页面内容
 * - onWindowStageDestroy: 窗口阶段销毁，释放UI资源
 * - onForeground: 应用进入前台
 * - onBackground: 应用进入后台
 * 
 * 日志管理：
 * - 使用hilog进行应用生命周期日志记录
 * - 错误处理和异常日志记录
 */

import { AbilityConstant, ConfigurationConstant, UIAbility, Want } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { window } from '@kit.ArkUI';

/**
 * 日志域标识
 * 用于区分不同模块的日志输出
 */
const DOMAIN = 0x0000;

/**
 * 应用入口Ability类
 * 
 * 继承自UIAbility，负责管理应用的生命周期和窗口状态
 * 这是HarmonyOS应用的主要入口点
 */
export default class EntryAbility extends UIAbility {
  /**
   * Ability创建时调用
   * 在应用启动时执行一次，用于初始化操作
   * 
   * @param want 启动Ability时的意图信息
   * @param launchParam 启动参数
   */
  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    try {
      // 设置应用颜色模式为系统默认
      // COLOR_MODE_NOT_SET表示跟随系统设置
      this.context.getApplicationContext().setColorMode(ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET);
    } catch (err) {
      // 颜色模式设置失败时的错误处理
      hilog.error(DOMAIN, 'testTag', 'Failed to set colorMode. Cause: %{public}s', JSON.stringify(err));
    }
    
    // 记录Ability创建日志
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onCreate');
  }

  /**
   * Ability销毁时调用
   * 在应用退出时执行，用于清理资源
   */
  onDestroy(): void {
    // 记录Ability销毁日志
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onDestroy');
  }

  /**
   * 窗口阶段创建时调用
   * 当主窗口创建完成时执行，用于加载页面内容
   * 
   * @param windowStage 窗口阶段对象，用于管理窗口内容
   */
  onWindowStageCreate(windowStage: window.WindowStage): void {
    // 记录窗口阶段创建日志
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onWindowStageCreate');

    // 加载页面内容到窗口
    // 这里加载SplashPage作为启动页面
    windowStage.loadContent('pages/SplashPage', (err) => {
      if (err.code) {
        // 页面加载失败时的错误处理
        hilog.error(DOMAIN, 'testTag', 'Failed to load the content. Cause: %{public}s', JSON.stringify(err));
        return;
      }
      
      // 页面加载成功日志
      hilog.info(DOMAIN, 'testTag', 'Succeeded in loading the content.');
    });
  }

  /**
   * 窗口阶段销毁时调用
   * 当主窗口被销毁时执行，用于释放UI相关资源
   */
  onWindowStageDestroy(): void {
    // 记录窗口阶段销毁日志
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onWindowStageDestroy');
  }

  /**
   * 应用进入前台时调用
   * 当应用从后台切换到前台时执行
   */
  onForeground(): void {
    // 记录应用进入前台日志
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onForeground');
  }

  /**
   * 应用进入后台时调用
   * 当应用从前台切换到后台时执行
   */
  onBackground(): void {
    // 记录应用进入后台日志
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onBackground');
  }
}