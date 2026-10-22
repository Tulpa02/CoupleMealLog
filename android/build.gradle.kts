allprojects {
    repositories {
        // 国内环境可把下面两行替换为阿里云镜像：
        // maven { url = uri("https://maven.aliyun.com/repository/google") }
        // maven { url = uri("https://maven.aliyun.com/repository/central") }
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
subprojects {
    project.evaluationDependsOn(":app")
}

// 对所有子项目（含 image_picker_android 等插件模块）关闭 Kotlin 增量编译，
// 规避 Windows 上 "Could not close incremental caches ... caches-jvm/jvm/kotlin" 报错。
subprojects {
    tasks.withType<org.jetbrains.kotlin.gradle.tasks.KotlinCompile>().configureEach {
        // 增量编译关闭（与 gradle.properties 中的 kotlin.incremental=false 双保险）
        incremental = false
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
