//
//  WellnessChallengeLibrary.swift
//  Lunixia
//

import Foundation

enum WellnessChallengeLibrary {
    static let all: [WellnessChallengeDefinition] = [
        sevenDaysOfPresence,
        mindfulMorning,
        selfCareDiscovery,
        eveningUnwind
    ]

    static func challenge(id: String) -> WellnessChallengeDefinition? {
        all.first { $0.id == id }
    }

    private static let fullSenses: [WellnessSensoryPrompt] = [
        .init("sight", "Sight", "Notice color, light, shape, distance, or movement.", icon: "window"),
        .init("sound", "Sound", "Notice a nearby sound and one farther away.", icon: "lovemusic"),
        .init("touch", "Touch", "Notice texture, temperature, pressure, or air on your skin.", icon: "hearthand"),
        .init("smell", "Smell", "Notice any scent, including a very faint or neutral one.", icon: "perfume"),
        .init("taste", "Taste", "Notice a lingering taste or take one unhurried sip.", icon: "teapot"),
        .init("body", "Body", "Notice posture, breath, tension, ease, or energy.", icon: "heartpulse")
    ]

    private static let reflectionCards: [WellnessInteractiveCardDefinition] = [
        .init(
            "surprise",
            "A small surprise",
            front: "Reveal a prompt",
            back: "What did you notice that you would normally have passed by?",
            icon: "sparklecircle"
        ),
        .init(
            "return",
            "Worth returning to",
            front: "Reveal a prompt",
            back: "Which moment from this challenge would you like to experience again?",
            icon: "repeat"
        ),
        .init(
            "carry",
            "Carry it forward",
            front: "Reveal a prompt",
            back: "What is one gentle way presence could fit into an ordinary day?",
            icon: "heartsparkle"
        )
    ]

    // MARK: - Seven Days of Presence

    static let sevenDaysOfPresence = WellnessChallengeDefinition(
        id: "seven-days-of-presence",
        title: "Seven Days of Presence",
        summary: "Notice the details, sounds, and small moments already around you.",
        category: .mindfulness,
        icon: "sparklecircle",
        estimatedMinutesLower: 5,
        estimatedMinutesUpper: 10,
        purpose: "Help you notice and appreciate your immediate surroundings and everyday experiences without asking you to make the day feel different first.",
        expectedExperience: "Seven varied invitations to observe, listen, pause, and reflect. You can move through them on consecutive days or whenever you have space.",
        completionMessage: "You practiced meeting ordinary moments with more attention. Your notes show what became visible when you gave the world a little more room.",
        experiences: [
            WellnessExperienceDefinition(
                id: "presence-01-surroundings",
                challengeID: "seven-days-of-presence",
                title: "Notice Your Surroundings",
                summary: "Pause long enough for familiar details to become visible again.",
                completionMessage: "You gave an ordinary place your full attention and noticed what was already waiting there.",
                steps: [
                    .reading(
                        id: "arrival",
                        title: "Arrive where you are",
                        body: "Choose a place where you can be still for a couple of minutes. You do not need silence or a beautiful view. Let the place be exactly as it is, and allow your attention to move more slowly than usual."
                    ),
                    .timer(
                        id: "observation-timer",
                        title: "Two minutes of looking",
                        prompt: "Let your eyes move gently around the space. Notice edges, colors, light, distance, and anything that changes while you watch.",
                        seconds: 120
                    ),
                    .reflection(
                        id: "noticed-reflection",
                        title: "What became visible?",
                        prompt: "Name one detail you had not noticed before, or one familiar detail that felt different when you slowed down."
                    )
                ]
            ),
            WellnessExperienceDefinition(
                id: "presence-02-listen",
                challengeID: "seven-days-of-presence",
                title: "Listen With Intention",
                summary: "Explore the layers of sound in one ordinary moment.",
                completionMessage: "You listened past the loudest sound and made room for the quieter layers around it.",
                steps: [
                    .reading(
                        id: "listening-intro",
                        title: "Let sound come to you",
                        body: "There is no need to identify every sound correctly. Listen for texture, rhythm, distance, and pauses. A busy room can hold as much to notice as a quiet one."
                    ),
                    .senses(
                        id: "sound-exploration",
                        title: "Explore the soundscape",
                        prompt: "Select each kind of sound you explored. Add a few words if an observation feels worth keeping.",
                        senses: [
                            .init("near", "Nearby", "A sound close to your body or immediate space.", icon: "lovemusic"),
                            .init("far", "Far away", "A sound beyond the room or farther into the environment.", icon: "starlocation"),
                            .init("steady", "Steady", "A continuous hum, rhythm, or repeated sound.", icon: "bubbles"),
                            .init("brief", "Brief", "A sound that appeared once and disappeared.", icon: "sparkbolt")
                        ],
                        minimum: 2
                    ),
                    .multiple(
                        id: "sound-qualities",
                        title: "What qualities did you notice?",
                        prompt: "Choose every quality that fits your listening experience.",
                        options: [
                            .init("layered", "Layered", "Several sounds occupied the same moment.", icon: "stackedboxes"),
                            .init("rhythmic", "Rhythmic", "A pattern repeated or shifted over time.", icon: "lovemusic"),
                            .init("unexpected", "Unexpected", "Something surprised or redirected you.", icon: "sparkle"),
                            .init("quiet-space", "Quiet between sounds", "The spaces between sounds felt noticeable.", icon: "moonzs"),
                            .init("body-response", "Felt in the body", "A sound changed your tension, breath, or attention.", icon: "heartpulse")
                        ],
                        minimum: 1
                    ),
                    .reflection(
                        id: "sound-reflection",
                        title: "One sound to remember",
                        prompt: "Which sound held your attention, and what made it interesting?"
                    )
                ]
            ),
            WellnessExperienceDefinition(
                id: "presence-03-senses",
                challengeID: "seven-days-of-presence",
                title: "Explore Your Senses",
                summary: "Choose an intention and follow it through your senses.",
                completionMessage: "You let your senses lead instead of rushing to explain the moment.",
                steps: [
                    .single(
                        id: "sense-intention",
                        title: "Choose an intention",
                        prompt: "How would you like to meet this sensory moment?",
                        options: [
                            .init("curiosity", "With curiosity", "Look for something you cannot predict.", icon: "sparklesearch"),
                            .init("softness", "With softness", "Notice without judging what appears.", icon: "heartfill"),
                            .init("detail", "With attention to detail", "Stay with small differences and textures.", icon: "searchwavy"),
                            .init("ease", "With ease", "Let the experience be simple and unforced.", icon: "zenlove")
                        ]
                    ),
                    .senses(
                        id: "full-sense-exploration",
                        title: "Follow what you notice",
                        prompt: "Explore at least three senses. Your observations can be brief and concrete.",
                        senses: fullSenses,
                        minimum: 3
                    ),
                    .reflection(
                        id: "sense-reflection",
                        title: "What drew you in?",
                        prompt: "Which sense felt most vivid today, and what did it help you notice?"
                    )
                ]
            ),
            WellnessExperienceDefinition(
                id: "presence-04-stillness",
                challengeID: "seven-days-of-presence",
                title: "A Moment of Stillness",
                summary: "Prepare, settle, and spend a few minutes without needing to perform calm.",
                completionMessage: "You made a little space for stillness without demanding that it feel any particular way.",
                steps: [
                    .stages(
                        id: "stillness-stages",
                        title: "Prepare for stillness",
                        prompt: "Move through each stage at your own pace.",
                        stages: [
                            "Choose a position that feels sustainable. Let your hands rest and adjust anything that is distracting you physically.",
                            "Notice where your body is supported. Feel the chair, floor, bed, or ground holding some of your weight.",
                            "Let your breathing remain natural. You are not trying to deepen it or make it perfectly even.",
                            "When thoughts or sounds pull your attention away, acknowledge them and return to one point of physical support."
                        ]
                    ),
                    .timer(
                        id: "stillness-timer",
                        title: "Three minutes of stillness",
                        prompt: "Stay with the feeling of support beneath you. Pause or finish whenever you need to.",
                        seconds: 180
                    ),
                    .rating(
                        id: "stillness-rating",
                        title: "How did stillness feel?",
                        prompt: "This is a description of this moment, not a score of how well you did.",
                        labels: ["Restless", "Uneven", "Neutral", "Settled", "Restful"]
                    )
                ]
            ),
            WellnessExperienceDefinition(
                id: "presence-05-ordinary-beauty",
                challengeID: "seven-days-of-presence",
                title: "The Beauty of Ordinary Things",
                summary: "Look closely at one everyday object or scene.",
                completionMessage: "You found detail in something ordinary by giving it more than a passing glance.",
                steps: [
                    .cards(
                        id: "observation-cards",
                        title: "Reveal an observation lens",
                        prompt: "Open the cards and choose the lens you want to use.",
                        cards: [
                            .init("history", "Signs of use", front: "What has this object lived through?", back: "Notice wear, repairs, softened edges, fingerprints, or other evidence of use.", icon: "timehand"),
                            .init("shape", "Shape and shadow", front: "Look at form, not function", back: "Notice the outline, negative space, and the shadow made by the object or scene.", icon: "objects"),
                            .init("color", "Unexpected color", front: "Look beyond the main color", back: "Find a small shift in tone, reflection, or color that is easy to overlook.", icon: "paintdrop")
                        ],
                        allowsSelection: true
                    ),
                    .activityChoice(
                        id: "ordinary-choice",
                        title: "Choose what to observe",
                        prompt: "Pick something available without arranging a special scene.",
                        options: [
                            .init("useful-object", "A useful object", "A cup, key, tool, bag, or something you handle often.", icon: "objects"),
                            .init("living-detail", "A living detail", "A plant, a person at a respectful distance, or movement outdoors.", icon: "sunflower"),
                            .init("small-scene", "A small scene", "A shelf, tabletop, window, or corner of a room.", icon: "window"),
                            .init("personal-item", "A personal item", "Something kept for comfort, memory, or meaning.", icon: "heartbox")
                        ]
                    ),
                    .stages(
                        id: "ordinary-guidance",
                        title: "Observe what you chose",
                        prompt: "Use the observation lens you selected, then follow the guidance for your subject.",
                        stages: ["Settle your attention.", "Look beyond first impressions."],
                        sourceStepID: "ordinary-choice",
                        adaptiveStages: [
                            "useful-object": [
                                "Notice how the object's shape supports what it does, including handles, edges, openings, or weight.",
                                "Look for a sign of repeated use and imagine the small moments that left it there."
                            ],
                            "living-detail": [
                                "Observe movement, pattern, color, or change without interrupting what you are watching.",
                                "Notice one detail that makes this living presence distinct from its surroundings."
                            ],
                            "small-scene": [
                                "Notice how the objects, light, and empty space relate to one another.",
                                "Find one detail at the edge of the scene that your attention skipped at first."
                            ],
                            "personal-item": [
                                "Notice the physical details before moving into memory or meaning.",
                                "Then let yourself remember why the item has remained part of your space."
                            ]
                        ]
                    ),
                    .reflection(
                        id: "ordinary-reflection",
                        title: "Describe what changed",
                        prompt: "What became interesting after you looked longer than usual?"
                    )
                ]
            ),
            WellnessExperienceDefinition(
                id: "presence-06-environment",
                challengeID: "seven-days-of-presence",
                title: "Connect With Your Environment",
                summary: "Choose the setting you have and explore it on its own terms.",
                completionMessage: "You connected with the environment you actually had, without needing it to be ideal.",
                steps: [
                    .activityChoice(
                        id: "environment-choice",
                        title: "Where are you exploring?",
                        prompt: "Choose the setting that best matches where you can spend a few minutes.",
                        options: [
                            .init("indoors", "Indoors", "A room, hallway, workspace, or shared interior.", icon: "lovehouse"),
                            .init("window", "Near a window", "A view, changing light, weather, or movement outside.", icon: "windowheart"),
                            .init("outdoors", "Outdoors", "A yard, sidewalk, park, porch, or open-air place.", icon: "sun"),
                            .init("in-transit", "In transit", "A safe seated pause while traveling or waiting.", icon: "starlocation")
                        ]
                    ),
                    .stages(
                        id: "environment-guidance",
                        title: "Explore this setting",
                        prompt: "The guidance below matches the environment you chose.",
                        stages: [
                            "Let your attention widen to include the whole setting.",
                            "Choose one stable detail and one changing detail.",
                            "Notice how your body responds to the place."
                        ],
                        sourceStepID: "environment-choice",
                        adaptiveStages: [
                            "indoors": [
                                "Notice how the room is arranged and where light gathers or fades.",
                                "Find one object placed for usefulness and one placed for comfort or expression.",
                                "Listen for signs of life or activity beyond your immediate space."
                            ],
                            "window": [
                                "Let your gaze settle on the nearest visible detail beyond the glass.",
                                "Notice one movement: weather, light, a person, an animal, or a shifting shadow.",
                                "Compare the feeling of the space inside with the scene outside."
                            ],
                            "outdoors": [
                                "Notice the temperature and movement of the air on your skin.",
                                "Look for one human-made detail and one naturally occurring detail.",
                                "Listen for the farthest sound you can hear without straining."
                            ],
                            "in-transit": [
                                "Keep your body safely settled and notice the shape of the waiting space around you.",
                                "Observe movement without following any one person for long.",
                                "Notice a repeated pattern in sound, signage, architecture, or motion."
                            ]
                        ]
                    ),
                    .reflection(
                        id: "environment-reflection",
                        title: "What did the place offer?",
                        prompt: "Record one detail that helped you feel more connected to where you were."
                    )
                ]
            ),
            WellnessExperienceDefinition(
                id: "presence-07-reflect",
                challengeID: "seven-days-of-presence",
                title: "Reflect on Your Experience",
                summary: "Look back at what presence revealed across the challenge.",
                completionMessage: "You gathered the moments that mattered and named how presence can belong in your life.",
                steps: [
                    .cards(
                        id: "presence-reflection-cards",
                        title: "Open the reflection cards",
                        prompt: "Reveal each card. Stay with whichever question feels most useful.",
                        cards: reflectionCards,
                        minimum: 3
                    ),
                    .multiple(
                        id: "presence-takeaways",
                        title: "What supported presence?",
                        prompt: "Choose any approaches that felt natural or worthwhile.",
                        options: [
                            .init("looking", "Looking closely", "Giving visual details more time.", icon: "searchwavy"),
                            .init("listening", "Listening intentionally", "Following layers of sound.", icon: "lovemusic"),
                            .init("stillness", "Being still", "Letting support and breath anchor attention.", icon: "zentime"),
                            .init("senses", "Using the senses", "Letting direct experience lead.", icon: "perfume"),
                            .init("reflection", "Writing afterward", "Putting a moment into your own words.", icon: "lovewrite")
                        ],
                        minimum: 1
                    ),
                    .reflection(
                        id: "presence-final-reflection",
                        title: "What would you like to remember?",
                        prompt: "Write about a moment from these experiences that you want to carry forward."
                    )
                ]
            )
        ]
    )

    // MARK: - The Mindful Morning

    static let mindfulMorning = WellnessChallengeDefinition(
        id: "mindful-morning",
        title: "The Mindful Morning",
        summary: "Explore flexible ways to begin the day with awareness and intention.",
        category: .mindfulness,
        icon: "sun",
        estimatedMinutesLower: 5,
        estimatedMinutesUpper: 10,
        purpose: "Explore how the first available moments of your day can feel more intentional, regardless of what time your morning begins.",
        expectedExperience: "Five adaptable experiences using intention, observation, the senses, personal choice, and reflection. Nothing requires a perfect routine or an early start.",
        completionMessage: "You explored mornings as lived moments rather than a rigid routine, and found choices that can make your own beginning feel more present.",
        experiences: [
            WellnessExperienceDefinition(
                id: "morning-01-gentle",
                challengeID: "mindful-morning",
                title: "A Gentle Beginning",
                summary: "Choose how you want to meet the next part of your day.",
                completionMessage: "You began with an intention that belonged to this morning, not an idealized one.",
                steps: [
                    .single(
                        id: "morning-intention",
                        title: "Choose today's quality",
                        prompt: "What would you like to bring into the next part of your morning?",
                        options: [
                            .init("steadiness", "Steadiness", "Move without rushing yourself unnecessarily.", icon: "balancewavy"),
                            .init("kindness", "Kindness", "Use a gentler tone with yourself.", icon: "hearthand"),
                            .init("clarity", "Clarity", "Give one thing your attention at a time.", icon: "brightbulb"),
                            .init("openness", "Openness", "Leave room for the morning to surprise you.", icon: "window")
                        ]
                    ),
                    .stages(
                        id: "gentle-activity",
                        title: "Put the intention into motion",
                        prompt: "Try this short activity without needing to change your whole morning.",
                        stages: [
                            "Settle your feet or body where you are and take one unforced breath.",
                            "Name the intention you chose in a short phrase, such as 'steady is enough.'",
                            "Choose one ordinary next action and imagine doing it with that quality.",
                            "Begin that action when you leave this experience."
                        ]
                    ),
                    .reflection(
                        id: "gentle-reflection",
                        title: "How could this intention help?",
                        prompt: "Write one sentence about where this quality might fit into your morning."
                    )
                ]
            ),
            WellnessExperienceDefinition(
                id: "morning-02-first-five",
                challengeID: "mindful-morning",
                title: "The First Five Minutes",
                summary: "Spend five available minutes observing before adding more input.",
                completionMessage: "You gave five minutes to direct experience before asking the day for anything else.",
                steps: [
                    .reading(
                        id: "five-minute-intro",
                        title: "Use the first available five",
                        body: "These do not need to be the first five minutes after waking. Choose any early moment when you can pause. Set aside extra input if it is safe to do so, and simply notice the beginning you are already having."
                    ),
                    .timer(
                        id: "five-minute-timer",
                        title: "Five minutes of observation",
                        prompt: "Notice breath, light, sound, and what your attention reaches for. There is nothing to fix during this timer.",
                        seconds: 300
                    ),
                    .single(
                        id: "morning-observation",
                        title: "What was most noticeable?",
                        prompt: "Choose the part of the experience that held the most attention.",
                        options: [
                            .init("body", "My body", "Energy, comfort, tension, or breath.", icon: "heartpulse"),
                            .init("surroundings", "My surroundings", "Light, temperature, objects, or movement.", icon: "window"),
                            .init("thoughts", "My thoughts", "Plans, memories, or mental momentum.", icon: "cloudmind"),
                            .init("sounds", "The sounds around me", "Near, distant, steady, or changing sound.", icon: "lovemusic")
                        ]
                    ),
                    .rating(
                        id: "five-minute-rating",
                        title: "How spacious did the pause feel?",
                        prompt: "Choose the description that best fits this particular morning.",
                        labels: ["Crowded", "Busy", "Neutral", "Open", "Very spacious"]
                    )
                ]
            ),
            WellnessExperienceDefinition(
                id: "morning-03-senses",
                challengeID: "mindful-morning",
                title: "Morning Senses",
                summary: "Meet the morning through direct sensory details.",
                completionMessage: "You met this morning through the details your senses could actually reach.",
                steps: [
                    .senses(
                        id: "morning-sensory-scan",
                        title: "Explore the morning",
                        prompt: "Choose at least three senses to explore. A neutral observation counts just as much as a pleasant one.",
                        senses: fullSenses,
                        minimum: 3
                    ),
                    .multiple(
                        id: "morning-sense-tone",
                        title: "What characterized the moment?",
                        prompt: "Select all the descriptions that fit.",
                        options: [
                            .init("soft", "Soft", "Muted light, quiet sound, or gentle sensation.", icon: "pillows"),
                            .init("bright", "Bright", "Clear light, vivid color, or alert energy.", icon: "sun"),
                            .init("cool", "Cool", "Cool air, water, surfaces, or color.", icon: "dropfill"),
                            .init("warm", "Warm", "Warmth in the air, body, food, or drink.", icon: "teapot"),
                            .init("still", "Still", "Little movement or a sense of pause.", icon: "zentime"),
                            .init("active", "Active", "Movement, sound, or people already in motion.", icon: "sparkbolt")
                        ],
                        minimum: 1
                    )
                ]
            ),
            WellnessExperienceDefinition(
                id: "morning-04-create",
                challengeID: "mindful-morning",
                title: "Create Your Morning Moment",
                summary: "Choose one realistic morning activity and make it more intentional.",
                completionMessage: "You shaped one real morning moment around your needs instead of following a prescribed routine.",
                steps: [
                    .activityChoice(
                        id: "morning-activity-choice",
                        title: "Choose an available moment",
                        prompt: "Pick the option that fits your life today.",
                        options: [
                            .init("drink", "Have a drink without multitasking", "Water, tea, coffee, or another morning drink.", icon: "teapot"),
                            .init("window", "Spend a moment by a window", "Notice light, weather, or movement outside.", icon: "windowheart"),
                            .init("stretch", "Move or stretch gently", "Choose comfortable movement rather than intensity.", icon: "catstretch"),
                            .init("prepare", "Prepare one thing slowly", "Food, clothing, a bag, or your immediate space.", icon: "objects")
                        ]
                    ),
                    .stages(
                        id: "morning-adaptive-steps",
                        title: "Make it intentional",
                        prompt: "Follow the steps for the activity you chose.",
                        stages: ["Begin slowly.", "Notice one sensory detail.", "Finish without rushing."],
                        sourceStepID: "morning-activity-choice",
                        adaptiveStages: [
                            "drink": [
                                "Place the drink within reach and set other input aside for a moment.",
                                "Notice temperature, scent, weight, and the first taste before taking another sip.",
                                "Finish a few sips at an unhurried pace and notice how your body responds."
                            ],
                            "window": [
                                "Settle where you can look outside without straining.",
                                "Notice the quality of light and one thing that is moving or changing.",
                                "Let your gaze widen before you return to the room."
                            ],
                            "stretch": [
                                "Choose a movement your body already knows and can do comfortably.",
                                "Move slowly enough to notice where the sensation begins and changes.",
                                "Pause in a neutral position and notice the after-feeling."
                            ],
                            "prepare": [
                                "Choose one small preparation instead of the whole morning list.",
                                "Notice the sequence of movements and the objects in your hands.",
                                "Finish that one preparation before deciding what comes next."
                            ]
                        ]
                    ),
                    .reflection(
                        id: "morning-moment-reflection",
                        title: "What made it feel intentional?",
                        prompt: "Note the part of the activity that changed when you gave it your full attention."
                    )
                ]
            ),
            WellnessExperienceDefinition(
                id: "morning-05-remember",
                challengeID: "mindful-morning",
                title: "A Morning Worth Remembering",
                summary: "Gather what worked and imagine a flexible way to return to it.",
                completionMessage: "You identified what makes a morning feel like yours, without turning it into another rule to follow.",
                steps: [
                    .cards(
                        id: "morning-reflection-cards",
                        title: "Reflect from a few angles",
                        prompt: "Reveal the cards and pause with the question that feels most relevant.",
                        cards: [
                            .init("quality", "The quality", front: "What feeling mattered?", back: "Which quality from these mornings would you welcome again: steadiness, space, curiosity, comfort, or something else?", icon: "heartsparkle"),
                            .init("realistic", "The realistic part", front: "What actually fit?", back: "Which practice worked because it respected the time and energy you had?", icon: "checkwavy"),
                            .init("permission", "The permission", front: "What can remain flexible?", back: "What expectation about mornings could you loosen while still caring for yourself?", icon: "heartlock")
                        ],
                        minimum: 3
                    ),
                    .reflection(
                        id: "morning-final-reflection",
                        title: "Describe a morning that feels like yours",
                        prompt: "Write about one small element you would like to remember. It can be a feeling, a choice, or a way of paying attention."
                    )
                ]
            )
        ]
    )

    // MARK: - Self-Care Discovery

    static let selfCareDiscovery = WellnessChallengeDefinition(
        id: "self-care-discovery",
        title: "Self-Care Discovery",
        summary: "Explore forms of care that feel enjoyable, supportive, and personally meaningful.",
        category: .selfCare,
        icon: "hearthand",
        estimatedMinutesLower: 5,
        estimatedMinutesUpper: 15,
        purpose: "Help you discover what care can look and feel like for you, without prescribing one universal routine or definition.",
        expectedExperience: "Seven choice-led experiences spanning comfort, environment, senses, enjoyment, and personal reflection.",
        completionMessage: "You explored care as something personal and responsive. Your choices and reflections form a useful picture of what support can mean for you.",
        experiences: [
            WellnessExperienceDefinition(
                id: "self-care-01-meaning",
                challengeID: "self-care-discovery",
                title: "What Feels Like Care?",
                summary: "Explore several forms of care and choose what resonates today.",
                completionMessage: "You named a form of care that fits your life today, without forcing it into someone else's definition.",
                steps: [
                    .cards(
                        id: "care-choice-cards",
                        title: "Explore forms of care",
                        prompt: "Reveal the cards, then select the one that feels most supportive today.",
                        cards: [
                            .init("comfort", "Comfort", front: "Care can soften the moment", back: "Choose warmth, familiar music, a comfortable position, or another small source of ease.", icon: "pillows"),
                            .init("space", "Space", front: "Care can create room", back: "Step away from input, clear one surface, or protect a few minutes from demands.", icon: "windowheart"),
                            .init("expression", "Expression", front: "Care can let something out", back: "Write, make, sing, move, speak, or express what has been held in.", icon: "lovewrite"),
                            .init("support", "Support", front: "Care can include connection", back: "Ask, answer honestly, spend time near someone safe, or let yourself receive help.", icon: "twinhearts")
                        ],
                        allowsSelection: true
                    ),
                    .reflection(
                        id: "care-meaning-reflection",
                        title: "Why does this feel like care?",
                        prompt: "Describe what the form of care you chose could offer you today."
                    )
                ]
            ),
            WellnessExperienceDefinition(
                id: "self-care-02-comfort",
                challengeID: "self-care-discovery",
                title: "A Moment of Comfort",
                summary: "Choose a realistic comfort and give it your attention.",
                completionMessage: "You treated comfort as a valid experience to notice, not something you had to earn.",
                steps: [
                    .activityChoice(
                        id: "comfort-choice",
                        title: "Choose a comfort",
                        prompt: "Pick something available and appropriate for you right now.",
                        options: [
                            .init("warm-drink", "A warm or refreshing drink", "Prepare or enjoy it without multitasking.", icon: "teapot"),
                            .init("comfortable-place", "A comfortable place", "Adjust your seat, blankets, lighting, or support.", icon: "sofa"),
                            .init("familiar-sound", "A familiar sound", "Music, ambient sound, or a voice that feels comforting.", icon: "lovemusic"),
                            .init("gentle-care", "A gentle care action", "Wash your face, use lotion, change clothes, or choose another soothing action.", icon: "creamjar")
                        ]
                    ),
                    .stages(
                        id: "comfort-steps",
                        title: "Let comfort be the activity",
                        prompt: "Follow the guidance that matches your choice.",
                        stages: ["Prepare the comfort.", "Notice it directly.", "Let it be enough."],
                        sourceStepID: "comfort-choice",
                        adaptiveStages: [
                            "warm-drink": [
                                "Prepare or place the drink where you can enjoy it safely.",
                                "Notice temperature, scent, and the feeling of the cup or glass in your hand.",
                                "Take several unhurried sips without adding another activity."
                            ],
                            "comfortable-place": [
                                "Adjust one thing that would help your body feel more supported.",
                                "Notice where your weight is held and where you can release unnecessary effort.",
                                "Stay for a few moments without asking the comfort to be productive."
                            ],
                            "familiar-sound": [
                                "Choose one piece of music or sound and set the volume at a comfortable level.",
                                "Listen for one familiar detail and one detail you have not noticed before.",
                                "Let the sound finish, or stop when the experience feels complete."
                            ],
                            "gentle-care": [
                                "Gather what you need so the action can remain simple.",
                                "Move slowly enough to notice texture, temperature, and touch.",
                                "Pause afterward and notice whether anything feels different."
                            ]
                        ]
                    ),
                    .rating(
                        id: "comfort-rating",
                        title: "How comforting was this today?",
                        prompt: "Describe this experience only. A low rating is useful information, not a failure.",
                        labels: ["Not comforting", "A little", "Somewhat", "Comforting", "Deeply comforting"]
                    )
                ]
            ),
            WellnessExperienceDefinition(
                id: "self-care-03-senses",
                challengeID: "self-care-discovery",
                title: "Care Through Your Senses",
                summary: "Notice which sensory qualities feel supportive today.",
                completionMessage: "You used your senses to discover what support felt like in this moment.",
                steps: [
                    .senses(
                        id: "care-sensory-exploration",
                        title: "Notice what feels supportive",
                        prompt: "Explore at least two senses. Choose what is accessible and comfortable for you.",
                        senses: fullSenses,
                        minimum: 2
                    ),
                    .activityChoice(
                        id: "sensory-care-choice",
                        title: "Choose one sensory care activity",
                        prompt: "Pick the activity that best matches what you noticed.",
                        options: [
                            .init("sound", "Create a supportive soundscape", "Choose quiet, music, or ambient sound intentionally.", icon: "lovemusic"),
                            .init("touch", "Choose a comforting texture", "Use clothing, a blanket, water, or another safe texture.", icon: "towel"),
                            .init("scent", "Spend time with a familiar scent", "Use food, soap, fresh air, or another comfortable scent.", icon: "perfume"),
                            .init("visual", "Rest your eyes on something pleasing", "Choose color, light, art, an object, or a view.", icon: "artboard")
                        ]
                    ),
                    .stages(
                        id: "sensory-care-guidance",
                        title: "Try the care activity",
                        prompt: "Follow the guidance for the sensory activity you chose.",
                        stages: ["Choose the sensory detail.", "Spend a moment with it."],
                        sourceStepID: "sensory-care-choice",
                        adaptiveStages: [
                            "sound": [
                                "Choose quiet, music, or ambient sound and set it at a comfortable level.",
                                "Listen long enough to notice how your attention or body responds."
                            ],
                            "touch": [
                                "Choose a safe texture or temperature that feels supportive right now.",
                                "Notice pressure, softness, warmth, coolness, or movement without rushing away."
                            ],
                            "scent": [
                                "Choose a safe, familiar scent from the air, food, soap, or another available source.",
                                "Notice the scent gently without trying to make it stronger."
                            ],
                            "visual": [
                                "Choose one view, color, object, or image and let your eyes settle there.",
                                "Notice the detail that makes it pleasant or interesting to you."
                            ]
                        ]
                    ),
                    .reading(
                        id: "sensory-permission",
                        title: "Keep the information",
                        body: "You do not need to turn this discovery into a permanent routine. Knowing which sensory qualities felt supportive today is already useful care information."
                    )
                ]
            ),
            WellnessExperienceDefinition(
                id: "self-care-04-space",
                challengeID: "self-care-discovery",
                title: "Make Space for Yourself",
                summary: "Shape a small amount of physical or mental space around your needs.",
                completionMessage: "You made a small, deliberate space for yourself within the day you actually had.",
                steps: [
                    .activityChoice(
                        id: "space-choice",
                        title: "What kind of space would help?",
                        prompt: "Choose the environment that feels most useful today.",
                        options: [
                            .init("quiet-corner", "A quieter corner", "Reduce sound or move to a less active area if available.", icon: "armchair"),
                            .init("clear-surface", "A cleared surface", "Make one small area easier to use or look at.", icon: "drawers"),
                            .init("outside-air", "A little open air", "Step outside or near an open window if comfortable.", icon: "window"),
                            .init("mental-space", "Mental space", "Set aside input and decisions for a few minutes.", icon: "cloudmind")
                        ]
                    ),
                    .stages(
                        id: "space-guidance",
                        title: "Create the space",
                        prompt: "Use the guidance for the kind of space you chose.",
                        stages: ["Choose the boundary.", "Make one adjustment.", "Spend a moment inside it."],
                        sourceStepID: "space-choice",
                        adaptiveStages: [
                            "quiet-corner": [
                                "Choose the quietest realistic place available, even if it is not silent.",
                                "Reduce one source of sound or visual input that you control.",
                                "Stay there for several breaths and notice what the reduced input offers."
                            ],
                            "clear-surface": [
                                "Choose one small surface rather than a whole room.",
                                "Move only what prevents the surface from serving you right now.",
                                "Pause and notice the space you created before deciding whether to do more."
                            ],
                            "outside-air": [
                                "Find a safe place where you can feel the air or see outside.",
                                "Notice temperature, movement, and one detail beyond your usual focus.",
                                "Let the change of environment mark a brief pause in the day."
                            ],
                            "mental-space": [
                                "Put one source of incoming information out of reach for a few minutes.",
                                "Write down any task you are afraid of forgetting, then set it aside.",
                                "Let yourself have a moment with no decision to make."
                            ]
                        ]
                    ),
                    .reflection(
                        id: "space-reflection",
                        title: "What did the space change?",
                        prompt: "Describe what became easier, quieter, or more noticeable after making room."
                    )
                ]
            ),
            WellnessExperienceDefinition(
                id: "self-care-05-enjoyment",
                challengeID: "self-care-discovery",
                title: "Rediscover Enjoyment",
                summary: "Let curiosity lead you toward a small, available source of enjoyment.",
                completionMessage: "You made room for enjoyment without requiring it to be impressive or productive.",
                steps: [
                    .cards(
                        id: "enjoyment-discovery-cards",
                        title: "Discover an invitation",
                        prompt: "Reveal the cards and select an invitation that feels approachable.",
                        cards: [
                            .init("return", "Return", front: "Revisit something familiar", back: "Choose a song, game, book, show, object, or activity you have enjoyed before.", icon: "repeat"),
                            .init("make", "Make", front: "Use your hands", back: "Doodle, arrange, cook, style, build, write, or make something small without judging the result.", icon: "sparklebrush"),
                            .init("play", "Play", front: "Choose lightness", back: "Do something silly, curious, playful, or simply unnecessary for a few minutes.", icon: "starballoons"),
                            .init("discover", "Discover", front: "Follow a small curiosity", back: "Look up, examine, listen to, or explore something because it interests you.", icon: "sparklesearch")
                        ],
                        allowsSelection: true
                    ),
                    .timer(
                        id: "enjoyment-activity",
                        title: "Five minutes for enjoyment",
                        prompt: "Give your chosen invitation a few uninterrupted minutes. You can continue afterward if you want to.",
                        seconds: 300
                    ),
                    .rating(
                        id: "enjoyment-rating",
                        title: "How enjoyable was the experience?",
                        prompt: "Rate the experience honestly. The purpose is discovery, not forcing enjoyment.",
                        labels: ["Not for me", "A little", "Neutral", "Enjoyable", "Very enjoyable"]
                    )
                ]
            ),
            WellnessExperienceDefinition(
                id: "self-care-06-comforts",
                challengeID: "self-care-discovery",
                title: "Your Personal Comforts",
                summary: "Name the comforts that are genuinely useful to you.",
                completionMessage: "You created a personal map of comforts that reflects your own needs and preferences.",
                steps: [
                    .multiple(
                        id: "personal-comforts",
                        title: "Which comforts belong to you?",
                        prompt: "Choose any that reliably or occasionally help. You do not need to select what is supposed to be comforting.",
                        options: [
                            .init("warmth", "Warmth", "A drink, shower, blanket, sunlight, or warm clothes.", icon: "teapot"),
                            .init("coolness", "Coolness", "Fresh air, cool water, lighter clothing, or a fan.", icon: "dropfill"),
                            .init("quiet", "Quiet", "Reduced sound and fewer demands on attention.", icon: "zentime"),
                            .init("sound", "Familiar sound", "Music, television, a podcast, ambient sound, or a trusted voice.", icon: "lovemusic"),
                            .init("movement", "Movement", "Stretching, walking, rocking, dancing, or changing position.", icon: "catstretch"),
                            .init("connection", "Connection", "Company, conversation, shared space, or asking for support.", icon: "twinhearts"),
                            .init("solitude", "Solitude", "Privacy, fewer interactions, or time without explaining yourself.", icon: "heartlock")
                        ],
                        minimum: 1
                    ),
                    .reflection(
                        id: "comforts-reflection",
                        title: "What makes a comfort work?",
                        prompt: "Choose one comfort and describe when it helps, when it does not, or how you prefer to experience it."
                    )
                ]
            ),
            WellnessExperienceDefinition(
                id: "self-care-07-definition",
                challengeID: "self-care-discovery",
                title: "What Self-Care Means to You",
                summary: "Reflect on the choices that made care feel personal and real.",
                completionMessage: "You defined self-care through lived experience, personal choice, and what genuinely supports you.",
                steps: [
                    .cards(
                        id: "care-reflection-cards",
                        title: "Open the reflection cards",
                        prompt: "Reveal every card and notice which question stays with you.",
                        cards: [
                            .init("surprised", "What surprised you?", front: "Reveal", back: "Which activity felt more supportive or enjoyable than you expected?", icon: "sparkle"),
                            .init("different", "What is different now?", front: "Reveal", back: "Has your definition of care widened, softened, or become more specific?", icon: "crossroads"),
                            .init("protect", "What deserves protection?", front: "Reveal", back: "Which kind of space, comfort, or enjoyment would you like to make easier to access?", icon: "starshield")
                        ],
                        minimum: 3
                    ),
                    .reflection(
                        id: "care-final-reflection",
                        title: "Define care in your own words",
                        prompt: "Complete this thought in any way that feels true: Self-care, for me, can be..."
                    )
                ]
            )
        ]
    )

    // MARK: - Evening Unwind

    static let eveningUnwind = WellnessChallengeDefinition(
        id: "evening-unwind",
        title: "Evening Unwind",
        summary: "Explore calming transitions that can make an evening feel more like your own.",
        category: .relaxation,
        icon: "moonzs",
        estimatedMinutesLower: 5,
        estimatedMinutesUpper: 10,
        purpose: "Explore calming activities that can make the transition into evening more enjoyable without assuming a specific bedtime, schedule, or household routine.",
        expectedExperience: "Five flexible experiences using reflection, environmental choice, the senses, personal comfort, and adaptable evening activities.",
        completionMessage: "You explored what helps an evening feel more settled and personal. Your choices offer a flexible set of ways to leave more of the day behind.",
        experiences: [
            WellnessExperienceDefinition(
                id: "evening-01-leave-day",
                challengeID: "evening-unwind",
                title: "Leave the Day Behind",
                summary: "Acknowledge what the day held and choose a transition away from it.",
                completionMessage: "You marked a boundary between what the day asked of you and the evening in front of you.",
                steps: [
                    .reflection(
                        id: "day-release-reflection",
                        title: "Name what you are carrying",
                        prompt: "What part of the day is still taking up the most space in your attention? A few words are enough."
                    ),
                    .activityChoice(
                        id: "transition-choice",
                        title: "Choose a transition",
                        prompt: "Pick a small action that can signal a change of pace.",
                        options: [
                            .init("change-clothes", "Change into something comfortable", "Let texture and fit mark a shift in the day.", icon: "pinnednote"),
                            .init("wash", "Wash the day away", "Wash your hands or face, shower, or use warm water intentionally.", icon: "shower"),
                            .init("clear", "Put away one reminder of the day", "Close a laptop, move a bag, clear one item, or dim a work light.", icon: "drawers"),
                            .init("music", "Play a transition song", "Choose one song that belongs to this part of the day.", icon: "lovemusic")
                        ]
                    ),
                    .stages(
                        id: "transition-guidance",
                        title: "Make the transition",
                        prompt: "Follow the short guidance for the action you chose.",
                        stages: ["Begin the transition.", "Notice the boundary it creates."],
                        sourceStepID: "transition-choice",
                        adaptiveStages: [
                            "change-clothes": [
                                "Choose clothing that feels comfortable for the part of the evening ahead.",
                                "As you change, notice texture and fit as a physical signal that the day has shifted."
                            ],
                            "wash": [
                                "Use water at a comfortable temperature and move a little more slowly than usual.",
                                "Notice the feeling afterward and let it mark a boundary from the day."
                            ],
                            "clear": [
                                "Choose one visible reminder of work, errands, or the day's demands.",
                                "Put it away or close it, then pause before deciding whether anything else needs attention."
                            ],
                            "music": [
                                "Choose one song for this transition and let it play without adding another activity.",
                                "When it ends, notice whether the evening feels even slightly more present."
                            ]
                        ]
                    ),
                    .reading(
                        id: "transition-close",
                        title: "Let one action be enough",
                        body: "Your whole day does not need to feel resolved before the evening can begin. Complete the transition you chose and let it serve as a small boundary."
                    )
                ]
            ),
            WellnessExperienceDefinition(
                id: "evening-02-quiet",
                challengeID: "evening-unwind",
                title: "Find Your Quiet",
                summary: "Choose the kind of quiet available to you and spend a few minutes there.",
                completionMessage: "You found a form of quiet that worked within your actual environment.",
                steps: [
                    .activityChoice(
                        id: "quiet-environment",
                        title: "What kind of quiet is available?",
                        prompt: "Quiet can mean less input, a steady sound, privacy, or simply a slower pace.",
                        options: [
                            .init("silence", "As little sound as possible", "Reduce controllable sound and settle somewhere comfortable.", icon: "moonzs"),
                            .init("steady-sound", "A steady background sound", "Use a fan, ambient sound, rain, or calm music.", icon: "lovemusic"),
                            .init("visual-quiet", "Visual quiet", "Dim a light, face away from clutter, or choose a simple view.", icon: "windowheart"),
                            .init("shared-quiet", "Quiet alongside someone", "Share space without needing conversation or entertainment.", icon: "twinhearts")
                        ]
                    ),
                    .stages(
                        id: "quiet-guidance",
                        title: "Prepare your quiet",
                        prompt: "Set up the kind of quiet you selected before beginning the timer.",
                        stages: ["Prepare the space.", "Settle into it."],
                        sourceStepID: "quiet-environment",
                        adaptiveStages: [
                            "silence": [
                                "Reduce one controllable source of sound and choose a supported position.",
                                "Let any remaining sounds exist without treating them as interruptions."
                            ],
                            "steady-sound": [
                                "Choose one steady sound and set it at a level that does not demand attention.",
                                "Let that sound form the background rather than listening for every change."
                            ],
                            "visual-quiet": [
                                "Dim or turn away from one visually demanding source while keeping the space safe.",
                                "Rest your eyes on a simple view, surface, or point of light."
                            ],
                            "shared-quiet": [
                                "Settle near the other person or animal without needing to fill the space.",
                                "Let shared presence be enough for the next few minutes."
                            ]
                        ]
                    ),
                    .timer(
                        id: "quiet-timer",
                        title: "Three minutes in your quiet",
                        prompt: "Let the environment hold your attention lightly. You can pause or finish at any time.",
                        seconds: 180
                    ),
                    .rating(
                        id: "quiet-rating",
                        title: "How settling was this quiet?",
                        prompt: "Choose the description that fits this evening, without treating it as a clinical measure.",
                        labels: ["Not settling", "Slightly", "Neutral", "Settling", "Very settling"]
                    )
                ]
            ),
            WellnessExperienceDefinition(
                id: "evening-03-senses",
                challengeID: "evening-unwind",
                title: "An Evening for the Senses",
                summary: "Notice how sensory details can change the feeling of an evening.",
                completionMessage: "You shaped the evening through sensory details that felt right for you.",
                steps: [
                    .senses(
                        id: "evening-sensory-exploration",
                        title: "Explore the evening atmosphere",
                        prompt: "Choose at least two senses to notice or gently adjust.",
                        senses: fullSenses,
                        minimum: 2
                    ),
                    .cards(
                        id: "evening-atmosphere-cards",
                        title: "Reveal an atmosphere idea",
                        prompt: "Open the cards and select an idea that suits this evening.",
                        cards: [
                            .init("light", "Light", front: "Adjust what you see", back: "Dim one light, close a bright screen, or choose a softer point of light while keeping the space safe.", icon: "candlesholder"),
                            .init("texture", "Texture", front: "Adjust what you feel", back: "Choose a comfortable fabric, pillow, temperature, or place for your body to settle.", icon: "pillows"),
                            .init("sound", "Sound", front: "Adjust what you hear", back: "Reduce one distracting sound or choose a steady sound you enjoy.", icon: "lovemusic"),
                            .init("scent", "Scent", front: "Notice the air", back: "Use fresh air, food, soap, tea, or another safe and familiar scent.", icon: "perfume")
                        ],
                        allowsSelection: true
                    )
                ]
            ),
            WellnessExperienceDefinition(
                id: "evening-04-ritual",
                challengeID: "evening-unwind",
                title: "Your Comfort Ritual",
                summary: "Choose a small ritual and let the guidance adapt to it.",
                completionMessage: "You created a comfort ritual from an activity that already fits your life.",
                steps: [
                    .activityChoice(
                        id: "ritual-choice",
                        title: "Choose an evening ritual",
                        prompt: "Choose something that sounds supportive, not something you think you should do.",
                        options: [
                            .init("drink", "Prepare a favorite drink", "Warm, cool, simple, or special to you.", icon: "teapot"),
                            .init("care", "Do a personal care activity", "Skin care, hair care, changing clothes, or another gentle action.", icon: "beautystation"),
                            .init("read", "Read or listen to something", "A book, article, poem, audiobook, or familiar story.", icon: "openbook"),
                            .init("stretch", "Stretch or move slowly", "Use comfortable movement to change pace.", icon: "catstretch")
                        ]
                    ),
                    .stages(
                        id: "ritual-guidance",
                        title: "Let the ritual unfold",
                        prompt: "Follow the steps for your choice without hurrying to finish.",
                        stages: ["Prepare.", "Participate.", "Notice the transition."],
                        sourceStepID: "ritual-choice",
                        adaptiveStages: [
                            "drink": [
                                "Prepare the drink with attention to sound, scent, and temperature.",
                                "Sit or stand somewhere comfortable and take several unhurried sips.",
                                "Notice what changes when the drink is the only activity for a moment."
                            ],
                            "care": [
                                "Gather what you need so the activity can remain simple.",
                                "Pay attention to touch, temperature, scent, and the pace of your hands.",
                                "Pause after finishing and notice how the activity marked the evening."
                            ],
                            "read": [
                                "Choose a comfortable place and a short stopping point.",
                                "Read or listen without checking how much is left.",
                                "At the stopping point, notice one image, idea, or phrase that stayed with you."
                            ],
                            "stretch": [
                                "Choose movements your body can do comfortably tonight.",
                                "Move slowly enough to feel each transition rather than reaching for intensity.",
                                "Finish in a supported position and notice the after-feeling."
                            ]
                        ]
                    ),
                    .reflection(
                        id: "ritual-reflection",
                        title: "What made it feel like a ritual?",
                        prompt: "Describe the detail that helped this activity feel intentional rather than automatic."
                    )
                ]
            ),
            WellnessExperienceDefinition(
                id: "evening-05-yours",
                challengeID: "evening-unwind",
                title: "An Evening That Feels Like Yours",
                summary: "Choose the qualities you value and describe an evening that makes room for them.",
                completionMessage: "You defined an evening by the qualities that matter to you, not by a schedule you have to copy.",
                steps: [
                    .multiple(
                        id: "evening-qualities",
                        title: "What would you like an evening to hold?",
                        prompt: "Choose the qualities that matter most. They do not need to appear every evening.",
                        options: [
                            .init("ease", "Ease", "Less urgency and fewer unnecessary demands.", icon: "zenlove"),
                            .init("comfort", "Comfort", "Physical support, familiar pleasures, or warmth.", icon: "pillows"),
                            .init("connection", "Connection", "Time with people, animals, or a sense of belonging.", icon: "twinhearts"),
                            .init("solitude", "Solitude", "Privacy and room to hear your own thoughts.", icon: "heartlock"),
                            .init("play", "Play", "Enjoyment, humor, creativity, or curiosity.", icon: "starballoons"),
                            .init("closure", "Closure", "A clear transition away from the day's demands.", icon: "checkwavy")
                        ],
                        minimum: 2
                    ),
                    .single(
                        id: "evening-anchor",
                        title: "Choose one anchor",
                        prompt: "Which kind of activity could most realistically support those qualities?",
                        options: [
                            .init("sensory", "A sensory adjustment", "Light, sound, temperature, scent, or texture.", icon: "perfume"),
                            .init("transition", "A transition action", "Changing clothes, washing, clearing, or closing something.", icon: "crossroads"),
                            .init("comfort", "A comfort activity", "A drink, care ritual, reading, movement, or rest.", icon: "hearthand"),
                            .init("boundary", "A boundary around my time", "Reducing input, requests, work, or decisions for a while.", icon: "starshield")
                        ]
                    ),
                    .reflection(
                        id: "evening-final-reflection",
                        title: "Describe an evening that feels like yours",
                        prompt: "Use your selected qualities and anchor to describe a flexible evening moment you would welcome again."
                    )
                ]
            )
        ]
    )
}
