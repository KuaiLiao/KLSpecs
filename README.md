# KLSpecs
fork repo specs

## Change

| Repo | Change | Version |
| --- | --- | --- |
| Masonry | 添加`UILayoutGuide`、`SafeArea`支持 | 1.2.3 |
| SnapKit | 把废弃方法拆分到`Deprecated` subspecies中，且默认不引用 | 5.7.1.2 |
| BlocksKit | 1. 删除苹果弃用的类扩展<br>2. 默认`subspec`改为`UIKit` | 2.2.6.1 |
| YYModel | 添加扩展 | 1.0.4.1 |
| YYText | 合并`YYText`原始`repo`中各位社区朋友提供的`Fix MR` | 1.0.7.1 |
| CombineCocoa | 无代码改动，仅修改`podspec`，Fix 在未开启`use_framework`的项目中混编报错问题 | 0.4.1.1 |
| RPStackable | 支持`ViewBuilder`语法 | 0.1.7.1 |
| SDWebImageWebPCoder | 支持`webp`图片的拉伸 | 0.14.6.1 |
| BRPickerView | 暴漏私有属性 | 2.9.7.1 |
| Bifrost | 添加通过`Proxy`进行事件分发功能 | 2.0.2 |
| OpusKit | 纯fork，无改动，仅调整`source url` | 1.5.2 |
| SwiftCollections | 为官方[repo](https://github.com/apple/swift-collections)添加`Cocoapods`支持 | 1.3.0 |


## TODO

- [x] SwiftCollections
  > 苹果[repo](https://github.com/apple/swift-collections)中 `InternalCollectionsUtilities`直接以subspec存在会出现编译错误，提的修复[MR](https://github.com/apple/swift-collections/pull/501)已合并，等待发布新版本。一种解决办法是让 `InternalCollectionsUtilities` 以独立`pod`形式存在并依赖。
