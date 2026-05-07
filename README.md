# KLSpecs
fork repo specs

## Change

| Repo | Change | Version |
| --- | --- | --- |
| [Masonry](https://github.com/KuaiLiao/Masonry) | 1.添加`UILayoutGuide`、`SafeArea`支持 <br>2. 新增`equalToSuperview` | 1.2.5 |
| [SnapKit](https://github.com/KuaiLiao/SnapKit) | 把废弃方法拆分到`Deprecated` subspecies中，且默认不引用 | 5.7.1.2 |
| [RPStackable](https://github.com/KuaiLiao/Stackable) | 1.支持`ViewBuilder`<br>2.新增`API` | 0.2.3 |
| [ZDTinyLayout](https://github.com/faimin/ZDTinyLayout) | `AutoLayout`语法糖 | 0.0.2 |
| [BlocksKit](https://github.com/KuaiLiao/BlocksKit) | 1. 删除苹果弃用的类扩展<br>2. 默认`subspec`改为`UIKit` | 2.2.6.1 |
| [YYModel](https://github.com/KuaiLiao/YYModel) | 添加扩展 | 1.0.4.4 |
| [YYText](https://github.com/KuaiLiao/YYText) | 1.合并`YYText`原始`repo`中各位社区朋友提供的`Fix MR` <br>2. Fix: compile error | 1.0.7.2 |
| [YYImage](https://github.com/KuaiLiao/YYImage) | 1.处理警告 <br>2.废弃方法 <br>3.提升最低支持版本 | 1.0.4.1 |
| [CombineCocoa](https://github.com/KuaiLiao/CombineCocoa) | 无代码改动，仅修改`podspec`，Fix 在未开启`use_framework`的项目中混编报错问题 | 0.4.1.1 |
| [SDWebImageWebPCoder](https://github.com/KuaiLiao/SDWebImageWebPCoder) | 支持`webp`图片的拉伸 | 0.14.6.1 |
| [BRPickerView](https://github.com/KuaiLiao/BRPickerView) | 暴漏私有属性 | 2.9.7.1 |
| [Bifrost](https://github.com/KuaiLiao/Bifrost) | 添加通过`Proxy`进行事件分发功能 | 2.0.2 |
| [OpusKit](https://github.com/Phonebooth/OpusKit) | 纯fork，无改动，仅调整`source url` | 1.5.2 |
| [SwiftCollections](https://github.com/apple/swift-collections) | 为官方[repo](https://github.com/apple/swift-collections)添加`Cocoapods`支持 | 1.3.0 |
| [FWPopupView](https://github.com/KuaiLiao/FWPopupView) | 1. 替换废弃的`SnapKit`语法<br>2. `left`改为`leading`，`right`改为`trailing` | 4.2.2.1 |
| [Builders](https://github.com/davdroman/swift-builders) | 支持`Cocoapods` | 0.10.0 |
| [ZDLibffi](https://github.com/faimin/ZDLibffi) | `libffi v3.5.2`添加`Cocoapods`支持 | 0.352.1 |
| [LookInsideServer](https://github.com/LookInsideApp/LookInside-Release) | 添加`Cocoapods`支持 | 0.2.0 |



## TODO

- [x] SwiftCollections
  > 苹果[repo](https://github.com/apple/swift-collections)中 `InternalCollectionsUtilities`直接以subspec存在会出现编译错误，提的修复[MR](https://github.com/apple/swift-collections/pull/501)已合并，等待发布新版本。一种解决办法是让 `InternalCollectionsUtilities` 以独立`pod`形式存在并依赖。
  >
  > 其他SwiftCollections Cocoapods版本：
  > - [https://github.com/Danie1s/swift-collections-podspec](https://github.com/Danie1s/swift-collections-podspec)
  > - [https://github.com/SwiftyLab/swift-collections](https://github.com/SwiftyLab/swift-collections)
