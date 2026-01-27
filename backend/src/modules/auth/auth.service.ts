import { Injectable, UnauthorizedException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { JwtService } from '@nestjs/jwt';
import { randomUUID } from 'crypto';
import * as bcrypt from 'bcrypt';
import { OAuth2Client } from 'google-auth-library';
import { User } from '../user/user.entity';
import { SignUpDto, SignInDto, GoogleSignInDto } from './dto/auth.dto';

@Injectable()
export class AuthService {
  private googleClient: OAuth2Client;

  constructor(
    @InjectRepository(User)
    private userRepository: Repository<User>,
    private jwtService: JwtService,
  ) {
    // Initialize Google OAuth client
    this.googleClient = new OAuth2Client();
  }

  async signUp(signUpDto: SignUpDto) {
    const { email, password, name } = signUpDto;

    // Check if user exists
    const existingUser = await this.userRepository.findOne({ where: { email } });
    if (existingUser) {
      throw new UnauthorizedException('Email already registered');
    }

    // Hash password
    const hashedPassword = await bcrypt.hash(password, 10);

    // Create user
    const user = this.userRepository.create({
      id: randomUUID(),
      email,
      password: hashedPassword,
      name,
      hasCompletedOnboarding: false, // New users must complete onboarding
    });

    await this.userRepository.save(user);

    // Generate token
    const token = this.generateToken(user);

    return {
      user: this.sanitizeUser(user),
      access_token: token,
    };
  }

  async signIn(signInDto: SignInDto) {
    const { email, password } = signInDto;

    // Find user
    const user = await this.userRepository
      .createQueryBuilder('user')
      .addSelect('user.password')
      .where('user.email = :email', { email })
      .getOne();
    if (!user) {
      throw new UnauthorizedException('Invalid credentials');
    }

    // Check password
    const isPasswordValid = await bcrypt.compare(password, user.password);
    if (!isPasswordValid) {
      throw new UnauthorizedException('Invalid credentials');
    }

    // Generate token
    const token = this.generateToken(user);

    return {
      user: this.sanitizeUser(user),
      access_token: token,
    };
  }

  async signInWithGoogle(googleSignInDto: GoogleSignInDto) {
    const { idToken } = googleSignInDto;

    try {
      // Verify Google ID token
      const ticket = await this.googleClient.verifyIdToken({
        idToken,
        audience: process.env.GOOGLE_CLIENT_ID, // Verify the token is for our app
      });

      const payload = ticket.getPayload();
      if (!payload) {
        throw new UnauthorizedException('Invalid Google token');
      }

      const { email, name, picture } = payload;

      // Check if user exists
      let user = await this.userRepository.findOne({ where: { email } });

      if (!user) {
        // Create new user with Google account
        user = this.userRepository.create({
          id: randomUUID(),
          email,
          name: name || email.split('@')[0],
          profilePicture: picture,
          // Generate a random password for Google users (they won't use it)
          password: await bcrypt.hash(Math.random().toString(36), 10),
          hasCompletedOnboarding: false, // Force onboarding for new Google users
        });

        await this.userRepository.save(user);
        console.log(`✅ Created new user from Google: ${email}`);
      } else {
        // Update profile picture if changed
        if (picture && user.profilePicture !== picture) {
          user.profilePicture = picture;
          await this.userRepository.save(user);
        }
        console.log(`✅ Existing user signed in with Google: ${email}`);
      }

      // Generate JWT token
      const token = this.generateToken(user);

      return {
        user: this.sanitizeUser(user),
        access_token: token,
      };
    } catch (error) {
      console.error('Google Sign-In error:', error);
      throw new UnauthorizedException('Invalid Google token');
    }
  }


  async validateUser(userId: string) {
    const user = await this.userRepository.findOne({ where: { id: userId } });
    if (!user) {
      throw new UnauthorizedException('User not found');
    }
    return this.sanitizeUser(user);
  }

  private generateToken(user: User) {
    const payload = { sub: user.id, email: user.email };
    return this.jwtService.sign(payload);
  }

  private sanitizeUser(user: User) {
    const { password, ...sanitized } = user;
    return sanitized;
  }
}
