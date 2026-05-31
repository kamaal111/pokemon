//
//  ImageFocusMetrics.swift
//  PokemonCardPipeline
//
//  Created by Kamaal M Farah on 5/31/26.
//

public enum ImageFocusMetrics {
    /// Measures local sharpness by applying a four-neighbor Laplacian kernel and returning the
    /// variance of the filtered values.
    ///
    /// Higher values usually indicate stronger edges and a sharper image region. The values are
    /// read as a row-major `width` by `height` grid. Returns `nil` when the grid is smaller than
    /// 3 by 3 or when `values.count` does not match `width * height`.
    ///
    /// For example, this 4 by 3 grid returns `6.25` because the two interior Laplacian values are
    /// `2` and `7`, whose variance is `6.25`:
    ///
    /// ```
    /// ImageFocusMetrics.laplacianVariance(
    ///     values: [
    ///         0, 0, 0, 0,
    ///         0, 1, 2, 0,
    ///         0, 0, 0, 0,
    ///     ],
    ///     width: 4,
    ///     height: 3
    /// )
    /// ```
    public static func laplacianVariance<Value: BinaryFloatingPoint>(
        values: [Value],
        width: Int,
        height: Int
    ) -> Value? {
        guard width >= minimumMetricDimension else { return nil }
        guard height >= minimumMetricDimension else { return nil }
        guard values.count == width * height else { return nil }

        var laplacianValues: [Value] = []
        laplacianValues.reserveCapacity((width - 2) * (height - 2))
        for y in 1..<(height - 1) {
            for x in 1..<(width - 1) {
                let center = value(values: values, width: width, x: x, y: y)
                let laplacian =
                    (4 * center)
                    - value(values: values, width: width, x: x - 1, y: y)
                    - value(values: values, width: width, x: x + 1, y: y)
                    - value(values: values, width: width, x: x, y: y - 1)
                    - value(values: values, width: width, x: x, y: y + 1)
                laplacianValues.append(laplacian)
            }
        }

        let mean = laplacianValues.reduce(0, +) / Value(laplacianValues.count)

        return laplacianValues.reduce(0) { sum, value in
            let difference = value - mean
            return sum + (difference * difference)
        } / Value(laplacianValues.count)
    }

    /// Measures edge strength by applying Sobel horizontal and vertical gradients and returning
    /// their mean magnitude.
    ///
    /// Higher values usually indicate stronger directional contrast and a sharper image region.
    /// The values are read as a row-major `width` by `height` grid. Returns `nil` when the grid is
    /// smaller than 3 by 3 or when `values.count` does not match `width * height`.
    ///
    /// For example, this 4 by 3 grid returns `3` because the two interior Sobel magnitudes are
    /// `4` and `2`, whose mean is `3`:
    ///
    /// ```
    /// ImageFocusMetrics.tenengradMean(
    ///     values: [
    ///         0, 0, 0, 0,
    ///         0, 1, 2, 0,
    ///         0, 0, 0, 0,
    ///     ],
    ///     width: 4,
    ///     height: 3
    /// )
    /// ```
    public static func tenengradMean<Value: BinaryFloatingPoint>(
        values: [Value],
        width: Int,
        height: Int
    ) -> Value? {
        guard width >= minimumMetricDimension else { return nil }
        guard height >= minimumMetricDimension else { return nil }
        guard values.count == width * height else { return nil }

        var gradientSum: Value = 0
        var count = 0
        for y in 1..<(height - 1) {
            for x in 1..<(width - 1) {
                let horizontal =
                    -value(values: values, width: width, x: x - 1, y: y - 1)
                    + value(values: values, width: width, x: x + 1, y: y - 1)
                    - (2 * value(values: values, width: width, x: x - 1, y: y))
                    + (2 * value(values: values, width: width, x: x + 1, y: y))
                    - value(values: values, width: width, x: x - 1, y: y + 1)
                    + value(values: values, width: width, x: x + 1, y: y + 1)
                let vertical =
                    value(values: values, width: width, x: x - 1, y: y - 1)
                    + (2 * value(values: values, width: width, x: x, y: y - 1))
                    + value(values: values, width: width, x: x + 1, y: y - 1)
                    - value(values: values, width: width, x: x - 1, y: y + 1)
                    - (2 * value(values: values, width: width, x: x, y: y + 1))
                    - value(values: values, width: width, x: x + 1, y: y + 1)
                gradientSum += ((horizontal * horizontal) + (vertical * vertical)).squareRoot()
                count += 1
            }
        }

        return gradientSum / Value(count)
    }

    private static func value<Value: BinaryFloatingPoint>(
        values: [Value],
        width: Int,
        x: Int,
        y: Int
    ) -> Value {
        values[(y * width) + x]
    }

    private static let minimumMetricDimension = 3
}
