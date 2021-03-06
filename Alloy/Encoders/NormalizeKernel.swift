//
//  NormalizeKernel.swift
//  Alloy
//
//  Created by Eugene Bokhan on 08/05/2019.
//

import Metal
import simd

final public class NormalizeKernel {

    // MARK: - Propertires

    public let pipelineState: MTLComputePipelineState
    private let deviceSupportsNonuniformThreadgroups: Bool

    // MARK: - Life Cycle

    public convenience init(context: MTLContext) throws {
        guard let library = context.library(for: Self.self)
        else { throw MetalError.MTLDeviceError.libraryCreationFailed }
        try self.init(library: library)
    }

    public init(library: MTLLibrary) throws {
        self.deviceSupportsNonuniformThreadgroups = library.device
                                                           .supports(feature: .nonUniformThreadgroups)
        let constantValues = MTLFunctionConstantValues()
        constantValues.set(self.deviceSupportsNonuniformThreadgroups,
                           at: 0)
        self.pipelineState = try library.computePipelineState(function: Self.functionName,
                                                              constants: constantValues)
    }

    // MARK: - Encode

    public func encode(sourceTexture: MTLTexture,
                       destinationTexture: MTLTexture,
                       mean: SIMD3<Float>,
                       std: SIMD3<Float>,
                       in commandBuffer: MTLCommandBuffer) {
        commandBuffer.compute { encoder in
            encoder.label = "Normalize Kernel"
            self.encode(sourceTexture: sourceTexture,
                        destinationTexture: destinationTexture,
                        mean: mean,
                        std: std,
                        using: encoder)
        }
    }

    public func encode(sourceTexture: MTLTexture,
                       destinationTexture: MTLTexture,
                       mean: SIMD3<Float>,
                       std: SIMD3<Float>,
                       using encoder: MTLComputeCommandEncoder) {
        encoder.set(textures: [sourceTexture,
                               destinationTexture])
        encoder.set(mean, at: 0)
        encoder.set(std, at: 1)

        if self.deviceSupportsNonuniformThreadgroups {
            encoder.dispatch2d(state: self.pipelineState,
                               exactly: destinationTexture.size)
        } else {
            encoder.dispatch2d(state: self.pipelineState,
                               covering: destinationTexture.size)
        }
    }

    public static let functionName = "normalize"
}
