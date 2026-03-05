allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

subprojects {
    if (project.path != ":app") {
        rootProject.findProject(":app")?.let {
            evaluationDependsOn(":app")
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
