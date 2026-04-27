package de.frohlfing.privault.privault

import android.os.Handler
import android.os.Looper
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import org.bouncycastle.crypto.generators.Argon2BytesGenerator
import org.bouncycastle.crypto.params.Argon2Parameters

object ArgonChannel {
    private const val CHANNEL = "de.frohlfing.privault/argon2"

    fun register(flutterEngine: FlutterEngine) {
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "hashPassword" -> {
                    val password = call.argument<ByteArray>("password")
                    val salt     = call.argument<ByteArray>("salt")
                    val memory      = call.argument<Int>("memory")      ?: 65536
                    val iterations  = call.argument<Int>("iterations")  ?: 4
                    val parallelism = call.argument<Int>("parallelism") ?: 4
                    val keyLength   = call.argument<Int>("keyLength")   ?: 32

                    if (password == null || salt == null) {
                        result.error("INVALID_ARGS", "password und salt sind Pflicht", null)
                        return@setMethodCallHandler
                    }

                    // Argon2 ist CPU-intensiv → Hintergrund-Thread, damit die UI nicht einfriert
                    Thread {
                        try {
                            val params = Argon2Parameters.Builder(Argon2Parameters.ARGON2_id)
                                .withSalt(salt)
                                .withParallelism(parallelism)
                                .withMemoryAsKB(memory)
                                .withIterations(iterations)
                                .withVersion(Argon2Parameters.ARGON2_VERSION_13)
                                .build()

                            val generator = Argon2BytesGenerator()
                            generator.init(params)

                            val hash = ByteArray(keyLength)
                            generator.generateBytes(password, hash, 0, hash.size)

                            Handler(Looper.getMainLooper()).post { result.success(hash) }
                        } catch (e: Exception) {
                            Handler(Looper.getMainLooper()).post {
                                result.error("ARGON2_ERROR", e.message, null)
                            }
                        }
                    }.start()
                }
                else -> result.notImplemented()
            }
        }
    }
}
