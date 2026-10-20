allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

rootProject.buildDir = file("../build")
subprojects {
    project.buildDir = File(rootProject.buildDir, project.name)
}
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.buildDir)
}
subprojects {
    afterEvaluate {
        if (project.hasProperty("android")) {
            val androidExt = project.extensions.findByName("android")
            if (androidExt != null) {
                try {
                    val getNamespace = androidExt.javaClass.getMethod("getNamespace")
                    val ns = getNamespace.invoke(androidExt)
                    if (ns == null) {
                        val setNamespace = androidExt.javaClass.getMethod("setNamespace", String::class.java)
                        setNamespace.invoke(androidExt, project.group.toString().ifEmpty { "com.example." })
                    }
                } catch (e: Exception) {
                }
            }
        }
    }
}
