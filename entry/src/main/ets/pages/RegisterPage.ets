/**
 * 注册页面 - 新用户注册功能
 * 
 * 功能概述：
 * - 提供用户注册表单和验证
 * - 支持用户名、密码、昵称设置
 * - 用户协议和隐私政策确认
 * - 注册成功后自动登录
 * 
 * 组件结构：
 * - Entry标记为独立页面入口
 * - Component封装注册逻辑
 * - 表单状态管理和验证
 * 
 * 状态管理：
 * - 表单输入字段状态
 * - 协议同意状态
 * - 错误消息提示状态
 * - 动画效果控制状态
 */

import type common from '@ohos.app.ability.common';
import promptAction from '@ohos.promptAction';
import picker from '@ohos.file.picker';
import router from '@ohos.router';
import { UserStore } from '../store/UserStore';

/**
 * 注册页面主组件
 */
@Entry
@Component
export struct RegisterPage {
  // 表单输入状态
  @State regUsername: string = '' // 用户名输入
  @State regPassword: string = '' // 密码输入
  @State regConfirmPassword: string = '' // 确认密码输入
  @State regNickname: string = '' // 昵称输入（可选）
  @State regAvatarUrl: string = '' // 头像地址（可选）
  @State registerAgree: boolean = false // 协议同意状态
  @State message: string = '' // 错误消息提示
  
  // 动画状态
  @State headerOpacity: number = 0 // 头部透明度
  @State headerOffset: number = 12 // 头部偏移量
  @State cardOpacity: number = 0 // 表单卡片透明度
  @State cardOffset: number = 18 // 表单卡片偏移量

  private hostCtx(): common.UIAbilityContext {
    return this.getUIContext().getHostContext() as common.UIAbilityContext;
  }

  /**
   * 处理用户注册
   * 包含表单验证和注册逻辑
   */
  private async handleRegister() {
    this.message = ''; // 清空错误消息
    
    // 协议同意验证
    if (!this.registerAgree) {
      this.message = '请先阅读并同意服务条款再注册';
      return;
    }
    
    // 执行注册操作
    const result = await UserStore.register(
      this.hostCtx(),
      this.regUsername.trim(),
      this.regPassword,
      this.regConfirmPassword,
      this.regNickname.trim() || this.regUsername.trim(),
      '这个人是新用户，快来打个招呼吧～',
      this.regAvatarUrl
    );

    // 注册结果处理
    if (result.ok === false) {
      this.message = result.message;
      return;
    }

    // 注册成功后的处理
    AppStorage.setOrCreate('session_version', 0);
    const v = (AppStorage.get('session_version') as number) ?? 0;
    AppStorage.set('session_version', v + 1);
    
    promptAction.showToast({ message: '注册成功，已登录' });
    await this.goBack();
  }

  /**
   * 返回上一页
   * 支持多种返回策略
   */
  private async goBack() {
    try {
      await router.back();
    } catch (e) {
      // 回退失败时跳转到我的页面
      await router.pushUrl({ url: 'pages/MinePage' });
    }
  }

  /**
   * 选择注册头像
   */
  private async chooseAvatar() {
    try {
      const photoPicker = new picker.PhotoViewPicker();
      const options = new picker.PhotoSelectOptions();
      options.MIMEType = picker.PhotoViewMIMETypes.IMAGE_TYPE;
      options.maxSelectNumber = 1;
      const result = await photoPicker.select(options);
      if (result?.photoUris?.length) {
        this.regAvatarUrl = result.photoUris[0];
      }
    } catch (e) {
      promptAction.showToast({ message: '头像选择失败，请稍后重试' });
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

  /**
   * UI构建方法
   * 创建注册表单界面
   */
  build() {
    Column() {
      // 顶部导航栏
      Flex({
        alignItems: ItemAlign.Center,
        justifyContent: FlexAlign.Center
      }) {
        // 返回按钮
        Text('←')
          .fontSize(20)
          .margin({ left: 12 })
          .onClick(async () => {
            await this.goBack();
          })

        Blank().layoutWeight(1)  // 左侧弹性空白

        // 页面标题
        Text('注册')
          .fontSize(22)
          .fontWeight(FontWeight.Bold)

        Blank().layoutWeight(1)  // 右侧弹性空白
      }
      .width('100%')
      .height(52)
      .opacity(this.headerOpacity)
      .translate({ x: 0, y: this.headerOffset })
      
      // 表单区域（可滚动）
      Scroll() {
        Column({ space: 12 }) {
          // 表单标题
          Row({ space: 8 }) {
            Text('注册').fontSize(16).fontWeight(FontWeight.Medium)
          }

          // 头像上传
          Row({ space: 12 }) {
            Stack({ alignContent: Alignment.Center }) {
              if (this.regAvatarUrl) {
                Image(this.regAvatarUrl)
                  .width(56)
                  .height(56)
                  .borderRadius(28)
                  .objectFit(ImageFit.Cover)
              } else {
                Image($r('app.media.startIcon'))
                  .width(56)
                  .height(56)
                  .borderRadius(28)
                  .backgroundColor('#4C6FFF')
                  .objectFit(ImageFit.Cover)
              }
            }
            .width(56)
            .height(56)
            .borderRadius(28)
            .border({ width: 1, color: '#E2E8F5' })
            Column({ space: 6 }) {
              Text('上传头像').fontSize(14).fontWeight(FontWeight.Medium)
              Text('可选').fontSize(12).opacity(0.6)
            }
            .layoutWeight(1)
            Button('选择图片', { type: ButtonType.Normal })
              .onClick(async () => {
                await this.chooseAvatar();
              })
          }
          .alignItems(VerticalAlign.Center)

          // 用户名输入框
          TextInput({ text: this.regUsername, placeholder: '设置用户名' })
            .onChange((v) => { this.regUsername = v; })
            .padding({ left: 12, right: 12 })
            .borderRadius(10)
            .backgroundColor('#F6F7FB')
          
          // 密码输入框
          TextInput({ text: this.regPassword, placeholder: '设置密码' })
            .type(InputType.Password)
            .onChange((v) => { this.regPassword = v; })
            .padding({ left: 12, right: 12 })
            .borderRadius(10)
            .backgroundColor('#F6F7FB')

          // 确认密码输入框
          TextInput({ text: this.regConfirmPassword, placeholder: '确认密码' })
            .type(InputType.Password)
            .onChange((v) => { this.regConfirmPassword = v; })
            .padding({ left: 12, right: 12 })
            .borderRadius(10)
            .backgroundColor('#F6F7FB')
          
          // 昵称输入框（可选）
          TextInput({ text: this.regNickname, placeholder: '昵称（可选）' })
            .onChange((v) => { this.regNickname = v; })
            .padding({ left: 12, right: 12 })
            .borderRadius(10)
            .backgroundColor('#F6F7FB')
          
          // 协议同意复选框
          Row({ space: 8 }) {
            Checkbox({ name: 'registerAgree', group: 'registerAgreement' })
              .select(this.registerAgree)
              .onChange((value: boolean) => {
                this.registerAgree = value;
                if (value) {
                  this.message = '';
                }
              })
            
            // 协议文本（可点击）
            Text() {
              TextSpan('我已阅读并同意').fontSize(12)
              TextSpan('《用户协议》')
                .fontSize(12)
                .fontColor('#3D6DFF')
                .onClick(() => this.showAgreement('user'))
              TextSpan('和').fontSize(12)
              TextSpan('《隐私政策》')
                .fontSize(12)
                .fontColor('#3D6DFF')
                .onClick(() => this.showAgreement('privacy'))
            }
            .onClick(() => {
              const next = !this.registerAgree;
              this.registerAgree = next;
              if (next) {
                this.message = '';
              }
            })
          }
          .alignItems(VerticalAlign.Center)
          .margin({ top: 4 })
          
          // 注册按钮
          Button('注册并登录', { type: ButtonType.Capsule })
            .onClick(async () => { await this.handleRegister(); })

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
        .opacity(this.cardOpacity)
        .translate({ x: 0, y: this.cardOffset })
      }
      .layoutWeight(1)
      .padding({ left: 16, right: 16, bottom: 16 })
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#EFF2F9')
    .onAppear(() => {
      // 页面显示时的动画效果
      animateTo({ duration: 220, curve: Curve.EaseOut }, () => {
        this.headerOpacity = 1;
        this.headerOffset = 0;
      });
      animateTo({ duration: 260, curve: Curve.EaseOut }, () => {
        this.cardOpacity = 1;
        this.cardOffset = 0;
      });
    })
  }
}