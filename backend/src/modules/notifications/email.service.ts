import { Injectable } from "@nestjs/common";
import { ConfigService } from "@nestjs/config";
import nodemailer, { Transporter } from "nodemailer";

@Injectable()
export class EmailService {
  private transporter?: Transporter;
  private fromAddress?: string;

  constructor(private configService: ConfigService) {
    const host = this.configService.get<string>("SMTP_HOST");
    const port = this.configService.get<number>("SMTP_PORT");
    const user = this.configService.get<string>("SMTP_USER");
    const pass = this.configService.get<string>("SMTP_PASS");
    const from = this.configService.get<string>("SMTP_FROM");

    if (host && port && user && pass) {
      this.transporter = nodemailer.createTransport({
        host,
        port,
        secure: port === 465,
        auth: { user, pass },
      });
      this.fromAddress = from || user;
    }
  }

  isEnabled() {
    return Boolean(this.transporter && this.fromAddress);
  }

  async sendAccountDeletion(email: string, name?: string) {
    if (!this.transporter || !this.fromAddress) return;
    await this.transporter.sendMail({
      from: this.fromAddress,
      to: email,
      subject: "Your Plurihive account was deleted",
      text: `Hi${name ? ` ${name}` : ""},\n\nYour Plurihive account was deleted. If you did not request this, please contact support@territoryfitness.com.\n\n- Plurihive Team`,
    });
  }
}
