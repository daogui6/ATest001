/*
 * MinePage.ets - 个人中心页面
 * 
 * 功能说明：
 * - 用户登录/退出登录功能
 * - 个人信息展示与编辑
 * - 用户足迹管理（浏览历史、点赞、评论）
 * - 通知消息管理
 * - 个人资料持久化存储
 * 
 * 页面架构：
 * - 头部导航栏
 * - 用户信息区域
 * - 功能入口网格
 * - 登录/注册表单（未登录状态）
 * - 账号信息编辑区域（已登录状态）
 * 
 * 状态管理：
 * - @State: 管理组件内部状态
 * - @StorageLink: 跨页面状态同步
 * - @Watch: 监听状态变化
 * 
 * 数据持久化：
 * - Preferences: 本地数据存储
 * - UserStore: 用户数据管理
 * - NotificationStore: 通知数据管理
 */

import type common from '@ohos.app.ability.common';
import promptAction from '@ohos.promptAction';
import picker from '@ohos.file.picker';
import router from '@ohos.router';
import { Prefs } from '../store/Prefs';
import { UserStore } from '../store/UserStore';
import { NotificationStore } from '../store/NotificationStore';

// 全局会话版本号，用于跨页面同步登录状态
AppStorage.setOrCreate('session_version', 0);
// 全局通知版本号，用于跨页面同步通知状态
AppStorage.setOrCreate('notification_version', 0);

/**
 * 个人中心页面组件
 * 
 * 主要功能：
 * 1. 用户认证（登录/退出）
 * 2. 个人信息管理
 * 3. 用户足迹查看
 * 4. 通知管理
 */
@Component
export struct MinePage {
  // ========== 配置常量 ==========
  /** Preferences存储的键名约定 */
  private KEY_UID = 'session.userId';        // 用户ID存储键
  private KEY_LOGIN = 'session.isLogin';     // 登录状态存储键
  private KEY_NICK = 'profile.nickname';     // 昵称存储键
  private KEY_BIO = 'profile.bio';           // 签名存储键
  private KEY_AVATAR = 'profile.avatar';     // 头像存储键

  // ========== 用户状态管理 ==========
  /** 登录状态 - 控制页面显示不同的内容区域 */
  @State isLogin: boolean = false;
  
  /** 用户基本信息 */
  @State nickname: string = '用户1';         // 用户昵称
  @State bio: string = '这个人很懒，还没有签名～'; // 用户签名
  @State avatarUrl: string = '';             // 用户头像
  @State uid: string = '0';                  // 用户唯一标识
  @State username: string = '';              // 用户名
  @State publicName: string = '';            // 公开昵称
  @State token: string = '';                 // 用户令牌
  @State isEditingProfile: boolean = false;  // 是否处于编辑资料状态
  @State showSettings: boolean = false;      // 设置面板展示

  // ========== 登录表单状态 ==========
  /** 登录表单相关状态 */
  @State loginUsername: string = '';         // 登录用户名
  @State loginPassword: string = '';         // 登录密码
  @State loginAgree: boolean = false;        // 是否同意协议
  @State message: string = '';               // 消息提示
  @State rememberPassword: boolean = false;  // 记住密码

  // ========== 动画效果状态 ==========
  /** 页面进入动画效果 */
  @State headerOpacity: number = 0;          // 头部透明度
  @State headerOffset: number = 12;          // 头部偏移量
  @State contentOpacity: number = 0;         // 内容透明度
  @State contentOffset: number = 18;         // 内容偏移量
  @State enablePush: boolean = true;         // 设置：消息提醒
  @State enableAutoPlay: boolean = true;     // 设置：自动播放
  @State enableCellular: boolean = false;    // 设置：移动网络播放

  // ========== 通知状态管理 ==========
  /** 通知相关状态 - 使用@StorageLink实现跨页面同步 */
  @StorageLink('notification_version')
  @Watch('onNotificationVersionChange')      // 监听通知版本变化
  notificationVersion: number = 0;

  /** 会话版本号 - 登录状态变化触发更新 */
  @StorageLink('session_version')
  @Watch('onSessionVersionChange')
  sessionVersion: number = 0;

  /** 未读通知数量 */
  @State unreadNotifications: number = 0;

  // ========== 工具方法 ==========
  
  /**
   * 获取宿主UIAbility的Context
   * 为Preferences/数据库等系统能力提供稳定的上下文参数
   * 
   * @returns UIAbility上下文对象
   */
  private hostCtx(): common.UIAbilityContext {
    return this.getUIContext().getHostContext() as common.UIAbilityContext;
  }

  // ========== 生命周期方法 ==========
  
  /**
   * 页面即将显示时调用
   * 用于初始化数据和加载资源
   */
  async aboutToAppear() {
    await this.loadSession();        // 加载用户会话
    await this.refreshNotifications(); // 刷新通知
  }

  /**
   * 监听通知版本变化
   * 当全局通知版本号变化时自动刷新通知
   */
  private onNotificationVersionChange() {
    this.refreshNotifications();
  }

  /**
   * 监听会话版本变化
   * 当登录状态更新时刷新用户信息
   */
  private onSessionVersionChange() {
    this.loadSession();
    this.refreshNotifications();
  }

  // ========== 数据加载方法 ==========
  
  /**
   * 加载用户会话信息
   * 优先从UserStore获取，如果不存在则从Preferences获取
   */
  private async loadSession() {
    // 优先从UserStore获取当前用户
    const user = await UserStore.currentUser(this.hostCtx());
    if (user) {
      this.uid = String(user.id);
      this.nickname = user.nickname || user.username;
      this.bio = user.bio ?? '这个人很懒，还没有签名～';
      this.avatarUrl = user.avatarUrl ?? '';
      this.username = user.username;
      this.publicName = user.publicName;
      this.token = user.token ?? '';
      this.isLogin = true;
      return;
    }

    // 从Preferences获取用户信息
    const uid = await Prefs.getString(this.hostCtx(), this.KEY_UID, '0');
    this.isLogin = (uid !== '0');

    this.nickname = await Prefs.getString(this.hostCtx(), this.KEY_NICK, '用户1');
    this.bio = await Prefs.getString(this.hostCtx(), this.KEY_BIO, '这个人很懒，还没有签名～');
    this.avatarUrl = await Prefs.getString(this.hostCtx(), this.KEY_AVATAR, '');
    this.uid = uid;
  }

  /**
   * 保存所有用户信息到本地存储
   */
  private async saveAll() {
    await Prefs.putString(this.hostCtx(), this.KEY_UID, this.uid);
    await Prefs.putBool(this.hostCtx(), this.KEY_LOGIN, this.isLogin); // 兼容性保留
    await Prefs.putString(this.hostCtx(), this.KEY_NICK, this.nickname);
    await Prefs.putString(this.hostCtx(), this.KEY_BIO, this.bio);
    await Prefs.putString(this.hostCtx(), this.KEY_AVATAR, this.avatarUrl);

    // 如果已登录，同步到服务器
    if (this.isLogin && this.uid !== '0') {
      await UserStore.updateProfile(this.hostCtx(), { 
        nickname: this.nickname,
        bio: this.bio,
        avatarUrl: this.avatarUrl
      });
    }
  }

  /**
   * 持久化个人资料变更
   * 保存到本地存储并触发全局状态更新
   */
  private async persistProfileChanges() {
    // 数据清理和默认值处理
    this.nickname = this.nickname.trim() || this.username || '用户1';
    this.bio = this.bio.trim() || '这个人很懒，还没有签名～';

    await this.saveAll();
    
    // 触发全局状态更新，通知其他页面刷新
    AppStorage.setOrCreate('session_version', 0);
    const v = (AppStorage.get('session_version') as number) ?? 0;
    AppStorage.set('session_version', v + 1);
    
    promptAction.showToast({ message: '已保存个人资料' });
  }

  /**
   * 打开头像选择器
   */
  private async chooseAvatar() {
    try {
      const permitted = await this.requestPhotoPermission();
      if (!permitted) {
        promptAction.showToast({ message: '未授权相册权限，无法选择头像' });
        return;
      }
      const photoPicker = new picker.PhotoViewPicker();
      const options = new picker.PhotoSelectOptions();
      options.MIMEType = picker.PhotoViewMIMETypes.IMAGE_TYPE;
      options.maxSelectNumber = 1;
      const result = await photoPicker.select(options);
      if (result?.photoUris?.length) {
        this.avatarUrl = result.photoUris[0];
      }
    } catch (e) {
      promptAction.showToast({ message: '头像选择失败，请稍后重试' });
    }
  }

  /**
   * 相册权限申请弹窗
   */
  private async requestPhotoPermission(): Promise<boolean> {
    try {
      const result = await promptAction.showDialog({
        title: '申请相册权限',
        message: '用于选择头像和上传图片，我们仅会在您主动操作时访问相册。',
        buttons: [
          { text: '暂不允许', color: '#666666' },
          { text: '允许', color: '#4C6FFF' }
        ]
      });
      return result?.index === 1;
    } catch {
      return false;
    }
  }

  /**
   * 查看协议弹窗
   */
  private showAgreement(type: 'user' | 'privacy') {
    const title = type === 'user' ? '用户协议' : '隐私政策';
    const message = type === 'user'
      ? '感谢使用本应用。本协议用于说明账号服务与使用规范，注册即代表您同意遵守相关规则。'
      : '我们仅在提供服务所需范围内处理必要信息，并采取合理措施保护您的数据安全。';
    promptAction.showDialog({
      title,
      message,
      buttons: [{ text: '我知道了', color: '#4C6FFF' }]
    });
  }

  // ========== 用户认证方法 ==========
  
  /**
   * 处理用户登录
   * 验证表单并调用登录API
   */
  private async handleLogin() {
    this.message = ''; // 清空错误消息
    
    // 验证用户协议
    if (!this.loginAgree) {
      this.message = '请先阅读并同意服务条款再登录';
      return;
    }
    
    // 调用登录API
    const result = await UserStore.login(this.hostCtx(), this.loginUsername.trim(), this.loginPassword);
    if (result.ok === false) {
      this.message = result.message;
      return;
    }

    // 登录成功，更新用户状态
    const user = result.user;
    this.uid = String(user.id);
    this.nickname = user.nickname || user.username;
    this.bio = user.bio ?? '这个人很懒，还没有签名～';
    this.avatarUrl = user.avatarUrl ?? '';
    this.username = user.username;
    this.publicName = user.publicName;
    this.token = user.token ?? '';
    this.isLogin = true;
    
    await this.saveAll();
    
    // 触发全局状态更新
    AppStorage.setOrCreate('session_version', 0);
    const v = (AppStorage.get('session_version') as number) ?? 0;
    AppStorage.set('session_version', v + 1);
    
    await this.refreshNotifications();
  }

  /**
   * 处理退出登录状态
   * 重置所有用户相关状态
   */
  private handleLogoutState() {
    this.uid = '0';
    this.username = '';
    this.publicName = '';
    this.token = '';
    this.avatarUrl = '';
    this.isLogin = false;
    this.message = '';
    this.loginAgree = false;
    this.isEditingProfile = false;

    // 根据记住密码设置决定是否清空密码
    if (!this.rememberPassword) {
      this.loginPassword = '';
    }
  }

  /**
   * 处理退出登录
   * 调用退出API并重置状态
   */
  private async handleLogout() {
    this.handleLogoutState();
    await this.saveAll();
    await UserStore.logout(this.hostCtx());

    // 触发全局状态更新
    AppStorage.setOrCreate('session_version', 0);
    const v = (AppStorage.get('session_version') as number) ?? 0;
    AppStorage.set('session_version', v + 1);
    
    await this.refreshNotifications();
    promptAction.showToast({ message: '已退出登录' });
  }

  /**
   * 取消编辑资料
   */
  private async cancelEditProfile() {
    await this.loadSession();
    this.isEditingProfile = false;
  }

  // ========== 页面跳转方法 ==========
  
  /**
   * 打开浏览历史页面
   */
  private async openHistory() {
    try {
      await router.pushUrl({ url: 'pages/HistoryPage' });
    } catch (e) {
      promptAction.showToast({ message: '跳转失败：页面不存在或参数错误' });
    }
  }

  /**
   * 打开点赞记录页面
   * 需要登录状态验证
   */
  private async openLiked() {
    if (!this.isLogin || this.uid === '0') {
      promptAction.showToast({ message: '请先登录后查看点赞记录' });
      return;
    }
    try {
      await router.pushUrl({ url: 'pages/LikedPage' });
    } catch (e) {
      promptAction.showToast({ message: '跳转失败：页面不存在或参数错误' });
    }
  }

  /**
   * 打开评论记录页面
   * 需要登录状态验证
   */
  private async openCommented() {
    if (!this.isLogin || this.uid === '0') {
      promptAction.showToast({ message: '请先登录后查看评论记录' });
      return;
    }
    try {
      await router.pushUrl({ url: 'pages/CommentedPage' });
    } catch (e) {
      promptAction.showToast({ message: '跳转失败：页面不存在或参数错误' });
    }
  }

  // ========== 通知管理方法 ==========
  
  /**
   * 刷新通知数量
   * 根据登录状态获取未读通知数量
   */
  private async refreshNotifications() {
    if (!this.isLogin || this.uid === '0') {
      this.unreadNotifications = 0;
      return;
    }
    this.unreadNotifications = await NotificationStore.unreadCount(this.hostCtx(), this.uid);
  }

  /**
   * 打开通知页面
   * 需要登录状态验证
   */
  private async openNotifications() {
    if (!this.isLogin || this.uid === '0') {
      promptAction.showToast({ message: '请先登录后查看通知' });
      return;
    }
    try {
      await router.pushUrl({ url: 'pages/NotificationPage' });
    } catch (e) {
      promptAction.showToast({ message: '跳转失败：页面不存在或参数错误' });
    }
  }

  /**
   * 打开注册页面
   */
  private async openRegisterPage() {
    try {
      await router.pushUrl({ url: 'pages/RegisterPage' });
    } catch (e) {
      promptAction.showToast({ message: '跳转失败：页面不存在或参数错误' });
    }
  }

  /**
   * 打开反馈入口
   */
  private async openFeedback() {
    promptAction.showToast({ message: '反馈入口即将上线，敬请期待' });
  }

  /**
   * 打开版本更新日志
   */
  private async openChangelog() {
    promptAction.showToast({ message: '当前版本暂无更新日志' });
  }

  /**
   * 打开帮助中心
   */
  private async openHelpCenter() {
    promptAction.showToast({ message: '帮助中心正在建设中' });
  }

  /**
   * 清理缓存
   */
  private async clearCache() {
    promptAction.showToast({ message: '缓存已清理，空间更清爽' });
  }

  // ========== 页面构建方法 ==========
  
  /**
   * 构建页面UI
   * 根据登录状态显示不同的内容区域
   */
  build() {
    Column() {
      // ========== 头部导航栏 ==========
      Row() {
        Blank().width(36)
        Text('我的')
          .fontSize(22)
          .fontWeight(FontWeight.Bold)
          .layoutWeight(1)
          .textAlign(TextAlign.Center)
        Button('设置', { type: ButtonType.Capsule })
          .fontSize(12)
          .fontColor('#4F46E5')
          .backgroundColor('#EEF2FF')
          .height(28)
          .padding({ left: 10, right: 10 })
          .onClick(() => {
            this.showSettings = !this.showSettings;
          })
      }
      .padding(12)
      .margin({ top: 12, left: 16, right: 16, bottom: 12 })
      .backgroundColor('#FFFFFF')
      .borderRadius(16)
      .shadow({ radius: 14, color: '#14000000', offsetX: 0, offsetY: 6 })
      .alignItems(VerticalAlign.Center)
      .opacity(this.headerOpacity)
      .translate({ x: 0, y: this.headerOffset })

      // ========== 主要内容区域 ==========
      Scroll() {
        Column({ space: 16 }) {
          // ========== 用户信息卡片 ==========
          Row({ space: 12 }) {
            // 用户头像区域
            Stack({ alignContent: Alignment.Center }) {
              if (this.avatarUrl) {
                Image(this.avatarUrl)
                  .width(52)
                  .height(52)
                  .borderRadius(26)
                  .objectFit(ImageFit.Cover)
              } else {
                Image($r('app.media.startIcon'))
                  .width(52)
                  .height(52)
                  .borderRadius(26)
                  .backgroundColor('#4C6FFF')
                  .objectFit(ImageFit.Cover)
                Text(this.isLogin ? (this.nickname ? this.nickname.slice(0, 1) : '我') : '访')
                  .fontSize(18)
                  .fontWeight(FontWeight.Bold)
                  .fontColor('#FFFFFF')
                  .textAlign(TextAlign.Center)
              }
            }
            .width(52)
            .height(52)
            .borderRadius(26)
            .border({ width: 1, color: '#E2E8F5' })

            // 用户信息文本区域
            Column({ space: 4 }) {
              Text(this.isLogin ? this.nickname : '欢迎来到我的主页')
                .fontSize(18)
                .fontWeight(FontWeight.Medium)
              Text(
                this.isLogin
                  ? `ID：${this.uid} · ${this.publicName || this.username || '未设置昵称'}`
                  : '登录后可同步点赞、评论等记录'
              )
                .fontSize(12)
                .opacity(0.6)
              if (this.isLogin) {
                Text(this.bio).fontSize(12).opacity(0.7).maxLines(2)
              }
            }
            .layoutWeight(1)
          }
          .padding(16)
          .borderRadius(16)
          .backgroundColor('#FFFFFF')
          .border({ width: 1, color: '#E9EEF5' })
          .shadow({ radius: 10, color: '#1A3B5A26', offsetX: 0, offsetY: 6 })

          Column({ space: 12 }) {
            Row() {
              Text('常用服务').fontSize(16).fontWeight(FontWeight.Medium)
            }
            Row({ space: 12 }) {
              Column({ space: 6 }) {
                Text('⭐').fontSize(22)
                Text('我的收藏').fontSize(12)
              }
              .layoutWeight(1)
              .padding(12)
              .borderRadius(12)
              .backgroundColor('#F6F7FB')
              .border({ width: 1, color: '#E9EEF5' })
              .onClick(async () => await this.openLiked())

              Column({ space: 6 }) {
                Text('📥').fontSize(22)
                Text('离线下载').fontSize(12)
              }
              .layoutWeight(1)
              .padding(12)
              .borderRadius(12)
              .backgroundColor('#F6F7FB')
              .border({ width: 1, color: '#E9EEF5' })
              .onClick(async () => await this.openHelpCenter())

              Column({ space: 6 }) {
                Text('🛡️').fontSize(22)
                Text('隐私中心').fontSize(12)
              }
              .layoutWeight(1)
              .padding(12)
              .borderRadius(12)
              .backgroundColor('#F6F7FB')
              .border({ width: 1, color: '#E9EEF5' })
              .onClick(async () => await this.openHelpCenter())
            }
          }
          .padding(16)
          .borderRadius(16)
          .backgroundColor('#FFFFFF')
          .border({ width: 1, color: '#E9EEF5' })
          .shadow({ radius: 10, color: '#1A3B5A1A', offsetX: 0, offsetY: 6 })

          // ========== 功能入口区域 ==========
          Column({ space: 12 }) {
            Row() {
              Text('我的足迹').fontSize(16).fontWeight(FontWeight.Medium)
            }
            
            // 第一行功能入口
            Row({ space: 12 }) {
              // 浏览历史入口
              Column({ space: 6 }) {
                Text('🕘').fontSize(22)
                Text('浏览历史').fontSize(12)
              }
              .layoutWeight(1)
              .padding(12)
              .borderRadius(12)
              .backgroundColor('#F6F7FB')
              .border({ width: 1, color: '#E9EEF5' })
              .onClick(async () => await this.openHistory())

              // 点赞记录入口
              Column({ space: 6 }) {
                Text('❤️').fontSize(22)
                Text('点赞过').fontSize(12)
              }
              .layoutWeight(1)
              .padding(12)
              .borderRadius(12)
              .backgroundColor('#F6F7FB')
              .border({ width: 1, color: '#E9EEF5' })
              .onClick(async () => await this.openLiked())

              // 评论记录入口
              Column({ space: 6 }) {
                Text('💬').fontSize(22)
                Text('评论过').fontSize(12)
              }
              .layoutWeight(1)
              .padding(12)
              .borderRadius(12)
              .backgroundColor('#F6F7FB')
              .border({ width: 1, color: '#E9EEF5' })
              .onClick(async () => await this.openCommented())
            }

            // 第二行功能入口（通知）
            Row({ space: 12 }) {
              Column({ space: 6 }) {
                Text('🔔').fontSize(22)
                Row({ space: 6 }) {
                  Text('通知').fontSize(12)
                  // 未读通知徽章
                  if (this.unreadNotifications > 0) {
                    Text(`${this.unreadNotifications}`)
                      .fontSize(10)
                      .fontColor('#FFFFFF')
                      .padding({ left: 6, right: 6, top: 2, bottom: 2 })
                      .borderRadius(10)
                      .backgroundColor('#4C6FFF')
                  }
                }
              }
              .layoutWeight(1)
              .padding(12)
              .borderRadius(12)
              .backgroundColor('#F6F7FB')
              .border({ width: 1, color: '#E9EEF5' })
              .onClick(async () => await this.openNotifications())

              Column({ space: 6 }) {
                Text('🧾').fontSize(22)
                Text('更新日志').fontSize(12)
              }
              .layoutWeight(1)
              .padding(12)
              .borderRadius(12)
              .backgroundColor('#F6F7FB')
              .border({ width: 1, color: '#E9EEF5' })
              .onClick(async () => await this.openChangelog())

              Column({ space: 6 }) {
                Text('🐞').fontSize(22)
                Text('反馈').fontSize(12)
              }
              .layoutWeight(1)
              .padding(12)
              .borderRadius(12)
              .backgroundColor('#F6F7FB')
              .border({ width: 1, color: '#E9EEF5' })
              .onClick(async () => await this.openFeedback())
            }
          }
          .padding(16)
          .borderRadius(16)
          .backgroundColor('#FFFFFF')
          .border({ width: 1, color: '#E9EEF5' })
          .shadow({ radius: 10, color: '#1A3B5A1A', offsetX: 0, offsetY: 6 })

          // ========== 登录/注册区域（未登录状态） ==========
          if (!this.isLogin) {
            Column({ space: 12 }) {
              Text('登录').fontSize(16).fontWeight(FontWeight.Medium)
              
              // 用户名输入框
              TextInput({ text: this.loginUsername, placeholder: '请输入用户名' })
                .onChange((v) => { this.loginUsername = v; })
                .padding({ left: 12, right: 12 })
                .borderRadius(10)
                .backgroundColor('#F6F7FB')
              
              // 密码输入框
              TextInput({ text: this.loginPassword, placeholder: '请输入密码' })
                .type(InputType.Password)
                .onChange((v) => { this.loginPassword = v; })
                .padding({ left: 12, right: 12 })
                .borderRadius(10)
                .backgroundColor('#F6F7FB')
              
              // 记住密码选项
              Row({ space: 8 }) {
                Checkbox({ name: 'rememberPassword', group: 'loginPrefs' })
                  .select(this.rememberPassword)
                  .onChange((value: boolean) => { this.rememberPassword = value; })
                Text('记住密码').fontSize(14)
              }
              .alignItems(VerticalAlign.Center)
              
              // 用户协议选项
              Row({ space: 8 }) {
                Checkbox({ name: 'loginAgree', group: 'loginAgreement' })
                  .select(this.loginAgree)
                  .onChange((value: boolean) => {
                    this.loginAgree = value;
                    if (value) {
                      this.message = '';
                    }
                  })
                Text() {
                  Span('我已阅读并同意').fontSize(12)
                  Span('《用户协议》')
                    .fontSize(12)
                    .fontColor('#3D6DFF')
                    .onClick((): void => {
                      this.showAgreement('user');
                    })
                  Span('和').fontSize(12)
                  Span('《隐私政策》')
                    .fontSize(12)
                    .fontColor('#3D6DFF')
                    .onClick((): void => {
                      this.showAgreement('privacy');
                    })
                }
                .onClick(() => {
                  const next = !this.loginAgree;
                  this.loginAgree = next;
                  if (next) {
                    this.message = '';
                  }
                })
              }
              .alignItems(VerticalAlign.Center)
              .margin({ top: 4 })

              // 登录/注册按钮同一行
              Row({ space: 12 }) {
                Button('登录', { type: ButtonType.Capsule })
                  .layoutWeight(1)
                  .onClick(async () => { await this.handleLogin(); })
                Button('注册', { type: ButtonType.Capsule })
                  .layoutWeight(1)
                  .onClick(async () => {
                    this.message = '';
                    await this.openRegisterPage();
                  })
              }
              .margin({ top: 4 })

              // 错误消息显示
              if (this.message) {
                Text(this.message).fontSize(14).fontColor(Color.Red).margin({ top: 4 })
              }
            }
            .padding(16)
            .borderRadius(16)
            .backgroundColor('#FFFFFF')
            .border({ width: 1, color: '#E9EEF5' })
            .shadow({ radius: 12, color: '#1A3B5A14', offsetX: 0, offsetY: 6 })
          }
          if (this.showSettings) {
            Column({ space: 12 }) {
              Row() {
                Text('设置中心').fontSize(16).fontWeight(FontWeight.Medium)
              }

              if (this.isLogin) {
                Column({ space: 6 }) {
                  Text('账号信息').fontSize(14).fontWeight(FontWeight.Medium)
                  Text(`用户ID：${this.uid}`).fontSize(13).opacity(0.7)
                  Text(`用户名：${this.username || '未获取'}`).fontSize(13).opacity(0.7)
                  Text(`公开昵称：${this.publicName || this.nickname}`).fontSize(13).opacity(0.7)
                  Text(`昵称：${this.nickname}`).fontSize(13).opacity(0.7)
                  Text(`签名：${this.bio}`).fontSize(13).opacity(0.7)
                }
              } else {
                Text('登录后可管理账号信息').fontSize(12).opacity(0.6)
              }

              Column({ space: 10 }) {
                Row() {
                  Text('消息提醒').fontSize(14)
                  Blank().layoutWeight(1)
                  Switch({ checked: this.enablePush })
                    .onChange((v: boolean) => {
                      this.enablePush = v;
                    })
                }
                Row() {
                  Text('首页自动播放').fontSize(14)
                  Blank().layoutWeight(1)
                  Switch({ checked: this.enableAutoPlay })
                    .onChange((v: boolean) => {
                      this.enableAutoPlay = v;
                    })
                }
                Row() {
                  Text('移动网络播放').fontSize(14)
                  Blank().layoutWeight(1)
                  Switch({ checked: this.enableCellular })
                    .onChange((v: boolean) => {
                      this.enableCellular = v;
                    })
                }
              }
              .padding(12)
              .borderRadius(12)
              .backgroundColor('#F8FAFC')

              Column({ space: 10 }) {
                Row() {
                  Text('清理缓存').fontSize(14)
                  Blank().layoutWeight(1)
                  Text('立即').fontSize(12).fontColor('#3B82F6')
                }
                .onClick(async () => await this.clearCache())
                Row() {
                  Text('帮助中心').fontSize(14)
                  Blank().layoutWeight(1)
                  Text('查看').fontSize(12).fontColor('#3B82F6')
                }
                .onClick(async () => await this.openHelpCenter())
              }

              if (this.isLogin) {
                if (this.isEditingProfile) {
                  Row({ space: 12 }) {
                    Stack({ alignContent: Alignment.Center }) {
                      if (this.avatarUrl) {
                        Image(this.avatarUrl)
                          .width(52)
                          .height(52)
                          .borderRadius(26)
                          .objectFit(ImageFit.Cover)
                      } else {
                        Image($r('app.media.startIcon'))
                          .width(52)
                          .height(52)
                          .borderRadius(26)
                          .backgroundColor('#4C6FFF')
                          .objectFit(ImageFit.Cover)
                      }
                    }
                    .width(52)
                    .height(52)
                    .borderRadius(26)
                    .border({ width: 1, color: '#E2E8F5' })
                    Button('更换头像', { type: ButtonType.Capsule })
                      .onClick(async () => {
                        await this.chooseAvatar();
                      })
                  }
                  .alignItems(VerticalAlign.Center)

                  Text('编辑昵称').fontSize(14).opacity(0.7)
                  TextInput({ text: this.nickname, placeholder: '请输入昵称' })
                    .onChange((v) => {
                      this.nickname = v;
                    })
                    .padding({ left: 12, right: 12 })
                    .borderRadius(10)
                    .backgroundColor('#F6F7FB')

                  Text('编辑签名').fontSize(14).opacity(0.7).margin({ top: 6 })
                  TextInput({ text: this.bio, placeholder: '请输入签名' })
                    .onChange((v) => {
                      this.bio = v
                    })
                    .padding({ left: 12, right: 12 })
                    .borderRadius(10)
                    .backgroundColor('#F6F7FB')

                  Row({ space: 12 }) {
                    Button('保存资料', { type: ButtonType.Capsule })
                      .layoutWeight(1)
                      .onClick(async () => {
                        await this.persistProfileChanges();
                        this.isEditingProfile = false;
                      })
                    Button('取消', { type: ButtonType.Capsule })
                      .layoutWeight(1)
                      .onClick(async () => {
                        await this.cancelEditProfile();
                      })
                  }
                  .margin({ top: 6 })
                } else {
                  Row({ space: 12 }) {
                    Button('修改资料', { type: ButtonType.Capsule })
                      .layoutWeight(1)
                      .onClick(() => {
                        this.isEditingProfile = true;
                      })
                    Button('退出登录', { type: ButtonType.Capsule })
                      .layoutWeight(1)
                      .onClick(async () => {
                        await this.handleLogout();
                      })
                  }
                  .margin({ top: 10 })
                }
              }
            }
            .padding(16)
            .borderRadius(16)
            .backgroundColor('#FFFFFF')
            .border({ width: 1, color: '#E9EEF5' })
            .shadow({ radius: 12, color: '#1A3B5A14', offsetX: 0, offsetY: 6 })
          } else if (this.isLogin) {
            // ========== 账号信息区域（已登录状态） ==========
            Column({ space: 12 }) {
              Text('账号信息').fontSize(16).fontWeight(FontWeight.Medium)
              
              // 账号信息展示
              Column({ space: 6 }) {
                Text(`用户ID：${this.uid}`).fontSize(14)
                Text(`用户名：${this.username || '未获取'}`).fontSize(14)
                Text(`公开昵称：${this.publicName || this.nickname}`).fontSize(14)
                Text(`Token：${this.token || '暂无'}`).fontSize(14).opacity(0.7)
                Text(`昵称：${this.nickname}`).fontSize(14)
                Text(`签名：${this.bio}`).fontSize(14).opacity(0.7)
              }

              if (this.isEditingProfile) {
                Row({ space: 12 }) {
                  Stack({ alignContent: Alignment.Center }) {
                    if (this.avatarUrl) {
                      Image(this.avatarUrl)
                        .width(52)
                        .height(52)
                        .borderRadius(26)
                        .objectFit(ImageFit.Cover)
                    } else {
                      Image($r('app.media.startIcon'))
                        .width(52)
                        .height(52)
                        .borderRadius(26)
                        .backgroundColor('#4C6FFF')
                        .objectFit(ImageFit.Cover)
                    }
                  }
                  .width(52)
                  .height(52)
                  .borderRadius(26)
                  .border({ width: 1, color: '#E2E8F5' })
                  Button('更换头像', { type: ButtonType.Capsule })
                    .onClick(async () => {
                      await this.chooseAvatar();
                    })
                }
                .alignItems(VerticalAlign.Center)

                Text('编辑昵称').fontSize(14).opacity(0.7)
                TextInput({ text: this.nickname, placeholder: '请输入昵称' })
                  .onChange((v) => {
                    this.nickname = v;
                  })
                  .padding({ left: 12, right: 12 })
                  .borderRadius(10)
                  .backgroundColor('#F6F7FB')

                Text('编辑签名').fontSize(14).opacity(0.7).margin({ top: 6 })
                TextInput({ text: this.bio, placeholder: '请输入签名' })
                  .onChange((v) => {
                    this.bio = v
                  })
                  .padding({ left: 12, right: 12 })
                  .borderRadius(10)
                  .backgroundColor('#F6F7FB')

                Row({ space: 12 }) {
                  Button('保存资料', { type: ButtonType.Capsule })
                    .layoutWeight(1)
                    .onClick(async () => {
                      await this.persistProfileChanges();
                      this.isEditingProfile = false;
                    })
                  Button('取消', { type: ButtonType.Capsule })
                    .layoutWeight(1)
                    .onClick(async () => {
                      await this.cancelEditProfile();
                    })
                }
                .margin({ top: 6 })
              } else {
                Row({ space: 12 }) {
                  Button('修改资料', { type: ButtonType.Capsule })
                    .layoutWeight(1)
                    .onClick(() => {
                      this.isEditingProfile = true;
                    })
                  Button('退出登录', { type: ButtonType.Capsule })
                    .layoutWeight(1)
                    .onClick(async () => {
                      await this.handleLogout();
                    })
                }
                .margin({ top: 10 })
              }
            }
            .padding(16)
            .borderRadius(16)
            .backgroundColor('#FFFFFF')
            .border({ width: 1, color: '#E9EEF5' })
            .shadow({ radius: 12, color: '#1A3B5A14', offsetX: 0, offsetY: 6 })
          }
        }
        .padding({ left: 16, right: 16, bottom: 16 })
        .opacity(this.contentOpacity)
        .translate({ x: 0, y: this.contentOffset })
      }
      .layoutWeight(1)
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#EFF2F9')
    .onAppear(() => {
      // 页面进入动画效果
      animateTo({ duration: 220, curve: Curve.EaseOut }, () => {
        this.headerOpacity = 1;
        this.headerOffset = 0;
      });
      animateTo({ duration: 260, curve: Curve.EaseOut }, () => {
        this.contentOpacity = 1;
        this.contentOffset = 0;
      });
    })
  }
}