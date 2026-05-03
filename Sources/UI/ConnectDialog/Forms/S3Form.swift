import DesignSystem
import SwiftUI

/// Form fields for Amazon S3 connections.
public struct S3Form: View {
    @Bindable private var viewModel: ConnectDialogViewModel

    /// Standard AWS regions shown in the region picker.
    static let regions: [String] = [
        "us-east-1", "us-east-2", "us-west-1", "us-west-2",
        "eu-west-1", "eu-west-2", "eu-west-3", "eu-central-1",
        "eu-north-1", "ap-east-1", "ap-south-1", "ap-northeast-1",
        "ap-northeast-2", "ap-northeast-3", "ap-southeast-1", "ap-southeast-2",
        "ca-central-1", "sa-east-1", "me-south-1", "af-south-1",
    ]

    public init(viewModel: ConnectDialogViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        Group {
            SDTextField("Custom Endpoint (optional)", text: self.$viewModel.hostname)
            self.bucketField
            self.regionPicker
            AuthSelector(viewModel: self.viewModel)
            if self.viewModel.authMode == .password {
                self.accessKeyFields
            }
        }
    }

    private var bucketField: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            SDTextField("Bucket", text: self.$viewModel.s3Bucket)
                .accessibilityValue(self.bucketAccessibilityValue)
            if let err = viewModel.validationErrors.first(where: { $0.field == .s3Bucket }) {
                self.inlineError(err.message)
            }
        }
    }

    private var bucketAccessibilityValue: String {
        if let err = viewModel.validationErrors.first(where: { $0.field == .s3Bucket }) {
            return "Error: \(err.message)"
        }
        return self.viewModel.s3Bucket
    }

    private var regionPicker: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Picker("Region", selection: self.$viewModel.s3Region) {
                ForEach(Self.regions, id: \.self) { region in
                    Text(region).tag(region)
                }
            }
            .accessibilityValue(self.regionAccessibilityValue)
            if let err = viewModel.validationErrors.first(where: { $0.field == .s3Region }) {
                self.inlineError(err.message)
            }
        }
    }

    private var regionAccessibilityValue: String {
        if let err = viewModel.validationErrors.first(where: { $0.field == .s3Region }) {
            return "Error: \(err.message)"
        }
        return self.viewModel.s3Region
    }

    private var accessKeyFields: some View {
        Group {
            VStack(alignment: .leading, spacing: Spacing.xs) {
                SDTextField("Access Key ID", text: self.$viewModel.awsAccessKeyID)
                    .accessibilityValue(self.accessKeyIDAccessibilityValue)
                if let err = viewModel.validationErrors.first(where: { $0.field == .awsAccessKeyID }) {
                    self.inlineError(err.message)
                }
            }
            VStack(alignment: .leading, spacing: Spacing.xs) {
                SecureField("Secret Access Key", text: self.$viewModel.awsSecretKey)
                    .textFieldStyle(.plain)
                    .padding(Spacing.xs)
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(Color(nsColor: .separatorColor))
                    )
                    .accessibilityValue(self.secretKeyAccessibilityValue)
                if let err = viewModel.validationErrors.first(where: { $0.field == .awsSecretKey }) {
                    self.inlineError(err.message)
                }
            }
        }
    }

    private var accessKeyIDAccessibilityValue: String {
        if let err = viewModel.validationErrors.first(where: { $0.field == .awsAccessKeyID }) {
            return "Error: \(err.message)"
        }
        return self.viewModel.awsAccessKeyID
    }

    private var secretKeyAccessibilityValue: String {
        if let err = viewModel.validationErrors.first(where: { $0.field == .awsSecretKey }) {
            return "Error: \(err.message)"
        }
        return ""
    }

    private func inlineError(_ message: String) -> some View {
        Text(message)
            .font(Font.system(size: 11))
            .foregroundStyle(Color(nsColor: .systemRed))
            .accessibilityValue("Error: \(message)")
    }
}
