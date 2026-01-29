import { Injectable } from "@nestjs/common";

export type LegalDocType = "privacy" | "terms" | "delete_account" | "data_usage";

@Injectable()
export class LegalService {
  getDocument(type: LegalDocType) {
    switch (type) {
      case "privacy":
        return {
          type,
          title: "Privacy Policy",
          updatedAt: "2026-01-29",
          body:
            "This Privacy Policy explains how Plurihive collects, uses, shares, and protects your information.\n\n" +
            "What we collect:\n" +
            "- Account data: name, email, profile image, login identifiers.\n" +
            "- Location data: precise and background location while tracking is active.\n" +
            "- Health & fitness data: steps, distance, calories, heart rate (only if you grant access).\n" +
            "- Activity data: routes, territories, points, workouts, streaks, and game progress.\n" +
            "- Device/app data: app version, device model, OS version, crash logs, and diagnostics.\n\n" +
            "How we use it:\n" +
            "- Provide tracking, territory capture, and map features.\n" +
            "- Calculate stats, leaderboards, rewards, and streaks.\n" +
            "- Sync progress across devices.\n" +
            "- Deliver notifications you enable.\n" +
            "- Protect security, prevent abuse, and improve performance.\n\n" +
            "Sharing:\n" +
            "- We do not sell your data.\n" +
            "- We share data only with service providers needed to operate the app (hosting, analytics, email).\n\n" +
            "Your choices:\n" +
            "- You can revoke permissions in system settings.\n" +
            "- You can delete your account in-app.\n\n" +
            "Retention & deletion:\n" +
            "- When you delete your account, we remove your account and activity data.\n" +
            "- We may retain limited records where required by law or for security audits.\n\n" +
            "Children:\n" +
            "- Plurihive is not intended for children under 13.\n\n" +
            "International transfers:\n" +
            "- Your data may be processed in countries where we or our providers operate.\n\n" +
            "Contact:\n" +
            "- If you have questions, contact support@territoryfitness.com.\n\n" +
            "Updates:\n" +
            "- We may update this policy and will show the latest date above.\n",
        };
      case "terms":
        return {
          type,
          title: "Terms of Service",
          updatedAt: "2026-01-29",
          body:
            "These Terms govern your use of Plurihive.\n\n" +
            "By using the app you agree to:\n" +
            "- Provide accurate account information.\n" +
            "- Use the app responsibly, safely, and lawfully.\n" +
            "- Avoid misuse, abuse, cheating, or interference with other users.\n\n" +
            "Gameplay:\n" +
            "- Points, territories, and rewards are for entertainment only.\n" +
            "- We may adjust game balance or features at any time.\n\n" +
            "Safety:\n" +
            "- You are responsible for safe use while moving. Do not use the app in dangerous situations.\n\n" +
            "Content:\n" +
            "- You grant us a limited license to host and display your activity and map data in the app.\n\n" +
            "Accounts:\n" +
            "- You may delete your account at any time.\n" +
            "- We may suspend or terminate accounts that violate these terms.\n\n" +
            "Disclaimers:\n" +
            "- The app is provided as-is without warranties.\n" +
            "- We are not liable for indirect damages arising from use of the app.\n\n" +
            "Changes:\n" +
            "- We may update these terms and will show the latest date above.\n",
        };
      case "delete_account":
        return {
          type,
          title: "Delete Account",
          updatedAt: "2026-01-29",
          body:
            "You can delete your account in Settings.\n\n" +
            "Steps:\n" +
            "1) Open Settings\n" +
            "2) Scroll to Danger zone\n" +
            "3) Tap Delete account and confirm\n\n" +
            "What gets deleted:\n" +
            "- Account profile, workouts, routes, territories, and rewards.\n\n" +
            "What may be retained:\n" +
            "- Limited records required by law or for security audits.\n\n" +
            "If you cannot access the app, contact support@territoryfitness.com.",
        };
      case "data_usage":
      default:
        return {
          type: "data_usage",
          title: "Data Usage Summary",
          updatedAt: "2026-01-29",
          body:
            "Here is a quick summary of how Plurihive uses data:\n\n" +
            "- Location: draw routes, capture territories, show nearby leaderboards.\n" +
            "- Health data: display steps, distance, calories, and heart rate (if enabled).\n" +
            "- Activity data: compute points, streaks, and rewards.\n" +
            "- Diagnostics: improve stability and performance.\n\n" +
            "Permissions used:\n" +
            "- Location (foreground/background while tracking)\n" +
            "- Activity recognition / fitness data (optional)\n" +
            "- Notifications (optional)\n\n" +
            "You can manage permissions anytime in system settings.",
        };
    }
  }
}
