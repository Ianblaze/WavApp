# Wav 🎵

**Find Your Perfect Harmony.**

Wav is a music-first matchmaking and social discovery app built with Flutter and Firebase. The core idea is simple but a little weird in the best way: instead of swiping on photos, you swipe on *songs*. Your taste in music is your fingerprint, and Wav uses that to figure out who you'd actually vibe with.

It's got a heavy Y2K bubblegum aesthetic, kinda like hot pink, neon purple, frosted glass, and interfaces that pulse and breathe like they're alive. It was a fun one to build.

---

##  Visual Tour

https://github.com/user-attachments/assets/5a6ae869-b400-4ae2-a9b4-6f324725aff4

<img width="351" height="779" alt="Screenshot 2026-04-25 113210" src="https://github.com/user-attachments/assets/8ba70609-6db6-40c9-ad92-02e1ad4a2c0c" />
<img width="356" height="779" alt="Screenshot 2026-04-25 113238" src="https://github.com/user-attachments/assets/4d2e6725-53b6-40d4-aa1d-395b3f04568f" />
<img width="352" height="783" alt="Screenshot 2026-04-25 113251" src="https://github.com/user-attachments/assets/6c1514f0-9356-4452-93f4-eb480f8dc901" />
<img width="353" height="781" alt="Screenshot 2026-04-25 113301" src="https://github.com/user-attachments/assets/8401c92e-800c-47db-b110-bf4b81d4302a" />
<img width="356" height="774" alt="Screenshot 2026-04-25 115913" src="https://github.com/user-attachments/assets/405cd792-82ae-42d4-9272-8598ecc70ba9" />
<img width="351" height="782" alt="Screenshot 2026-04-25 121959" src="https://github.com/user-attachments/assets/211f6253-9187-4570-976d-ad8dac90deef" />
<img width="353" height="777" alt="Screenshot 2026-04-25 121450" src="https://github.com/user-attachments/assets/62649397-f279-4856-944c-c289dfbfee4a" />
<img width="357" height="785" alt="Screenshot 2026-04-25 121437" src="https://github.com/user-attachments/assets/be6783ab-9bcc-4e10-b8fa-d291ed81e283" />
<img width="349" height="783" alt="Screenshot 2026-04-25 122039" src="https://github.com/user-attachments/assets/ef8e7331-1628-4d04-a3c4-a82041cb9cf9" />

### Landing & Authentication
*The first impression of the Wav experience.*

The landing screen leans into the aesthetic hard — abstract wave shapes, cinematic animation, the whole thing. Auth options are straightforward: Email/Password, Google, or Guest Mode if you just want to poke around.

**Guest Mode** is worth calling out specifically for you busy recruiters as it auto-seeds a profile and drops a pre-built "Welcome Match" (Melody ✨) so recruiters or testers can see the full experience without creating an account.


### Interactive Onboarding
*Mapping your sonic DNA.*

Rather than asking a bunch of questions, onboarding is a visual experience. You pick favorite artists from a curated grid, select genres in a bubble-style UI, and behind the scenes the app is quietly building a multi-dimensional embedding vector from your choices. That vector becomes your musical fingerprint for matching.

<img width="352" height="623" alt="Screenshot 2026-04-25 123150" src="https://github.com/user-attachments/assets/51d06311-56db-43ef-afd1-82d13a179ce9" />
<img width="347" height="781" alt="Screenshot 2026-04-25 123200" src="https://github.com/user-attachments/assets/a027350e-d36f-4433-8841-05c023444608" />
<img width="350" height="780" alt="Screenshot 2026-04-25 123224" src="https://github.com/user-attachments/assets/35ed92d3-309f-48e6-a021-d563c6eb3070" />
<img width="351" height="778" alt="Screenshot 2026-04-25 123237" src="https://github.com/user-attachments/assets/68b8e16a-9756-4ff2-b293-83f19e25be40" />


### The Wav Tab (Core Swiping)
*The heart of the app.*

This is where you actually use the thing. A library of 100+ mainstream tracks gets served up as swipeable cards. Swipe **down to like**, swipe **up to pass**. The UI dynamically shifts color based on the mood of whatever song is on screen so the whole experience feels alive. Haptic feedback makes every swipe feel intentional and satisfying.


### Matches & Chat
*Where connections happen.*

Matching isn't just "you both liked the same song." It's a three-layer system: Cosine Similarity on your taste embeddings, Jaccard Index on shared likes, and a Gale-Shapley mutual interest check. Each match screen tells you *why* you matched: shared artists, genres, a similarity score which never feels arbitrary.

Chat is real-time with a clean frosted-glass interface. No clutter, just conversation.


---

##  Technical Architecture

### Frontend
- **Framework**: Flutter (for high-performance 60fps animations)
- **State Management**: Provider (Atomic updates for swiping and likes)
- **UI Architecture**: Custom Design System leveraging Glassmorphism, HSL-based color tokens, and Y2K aesthetic standards.

### Backend (Serverless)
- **Database**: Google Firebase Firestore (Real-time data sync)
- **Auth**: Firebase Authentication
- **Matching Engine**: Client-side implementation of 3-layer similarity algorithms:
  - **Layer 1**: Content-based filtering via embedding vectors.
  - **Layer 2**: Collaborative filtering on user interaction histories.
  - **Layer 3**: Reciprocal logic for mutual connection verification.

---

##  Installation & Setup

1. **Clone the Repo**
   ```bash
   git clone https://github.com/yourusername/wav-app.git
   ```

2. **Environment Configuration**
   - Run `flutter pub get` to install dependencies.
   - Configure Firebase: Add `google-services.json` (Android) and `GoogleService-Info.plist` (iOS).
   - Ensure Firestore rules allow anonymous user data creation.

3. **Run the App**
   ```bash
   flutter run
   ```

---

##  Design Philosophy: Y2K Bubblegum

The aesthetic is intentional and a little maximal. I decided to go with a card architecture to create something unique, staying true to the vibrant early 2000s futuristic vibe:
- **Palette**: Hot Pink (#FF6FE8), Neon Purple (#B69CFF), and Cloud Lavender.
- **Visuals**: Soft gradients, organic curves, and translucent "frosted glass" containers.
- **Experience**: "Alive" interfaces that react to music data, making social discovery feel like a rhythm game.

---
DISCLAIMER: Im currently still largely working on the app and brainstorming new features daily, while a few are still incomplete or in their infant stage. For native testing i have deployed wav at https://wavofficial.web.app/ if youre curious enough. Wav is a Mobile first experience so its highly recommended you test it on your phone rather than a desktop/laptop. Swipe away!
