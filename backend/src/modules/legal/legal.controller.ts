import { Controller, Get, Param, NotFoundException } from "@nestjs/common";
import { LegalService, LegalDocType } from "./legal.service";

@Controller("legal")
export class LegalController {
  constructor(private legalService: LegalService) {}

  @Get(":type")
  getDoc(@Param("type") type: string) {
    const normalized = type.replace("-", "_").toLowerCase();
    const allowed: LegalDocType[] = [
      "privacy",
      "terms",
      "delete_account",
      "data_usage",
    ];
    if (!allowed.includes(normalized as LegalDocType)) {
      throw new NotFoundException("Legal document not found");
    }
    return this.legalService.getDocument(normalized as LegalDocType);
  }
}
