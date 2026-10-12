/*
 * pocket-input: reads gamepads with SDL3 and prints one event per line
 * on stdout for the shell to consume.
 *
 *   ready
 *   connected <name>
 *   disconnected <name>
 *   down <button>
 *   up <button>
 *
 * Buttons: a b x y l1 r1 lt rt l3 r3 select start home up down left right
 *
 * Face buttons are named by the letter printed on the controller (as SDL
 * reports it), so "a" is always the button labelled A. The left stick and
 * the triggers are turned into button presses with some hysteresis.
 *
 * It never grabs the device, so games still receive all input.
 */

#include <SDL3/SDL.h>
#include <stdbool.h>
#include <stdio.h>
#include <string.h>

#define STICK_ON     16000
#define STICK_OFF    10000
#define TRIGGER_ON   16000
#define TRIGGER_OFF   8000
#define MAX_PADS        8

typedef struct {
    SDL_JoystickID id;
    SDL_Gamepad *pad;
    bool left, right, up, down, lt, rt;
} Pad;

static Pad pads[MAX_PADS];

static void emit(const char *event, const char *name)
{
    printf("%s%s%s\n", event, *name ? " " : "", name);
    fflush(stdout);
}

static Pad *find_pad(SDL_JoystickID id)
{
    for (int i = 0; i < MAX_PADS; i++)
        if (pads[i].pad && pads[i].id == id)
            return &pads[i];
    return NULL;
}

static const char *face_name(SDL_Gamepad *pad, SDL_GamepadButton button)
{
    switch (SDL_GetGamepadButtonLabel(pad, button)) {
    case SDL_GAMEPAD_BUTTON_LABEL_A:        return "a";
    case SDL_GAMEPAD_BUTTON_LABEL_B:        return "b";
    case SDL_GAMEPAD_BUTTON_LABEL_X:        return "x";
    case SDL_GAMEPAD_BUTTON_LABEL_Y:        return "y";
    case SDL_GAMEPAD_BUTTON_LABEL_CROSS:    return "a";
    case SDL_GAMEPAD_BUTTON_LABEL_CIRCLE:   return "b";
    case SDL_GAMEPAD_BUTTON_LABEL_SQUARE:   return "x";
    case SDL_GAMEPAD_BUTTON_LABEL_TRIANGLE: return "y";
    default: break;
    }
    /* Unknown labels: fall back to positions in the common Xbox layout */
    switch (button) {
    case SDL_GAMEPAD_BUTTON_SOUTH: return "a";
    case SDL_GAMEPAD_BUTTON_EAST:  return "b";
    case SDL_GAMEPAD_BUTTON_WEST:  return "x";
    case SDL_GAMEPAD_BUTTON_NORTH: return "y";
    default: return NULL;
    }
}

static const char *button_name(SDL_Gamepad *pad, SDL_GamepadButton button)
{
    switch (button) {
    case SDL_GAMEPAD_BUTTON_SOUTH:
    case SDL_GAMEPAD_BUTTON_EAST:
    case SDL_GAMEPAD_BUTTON_WEST:
    case SDL_GAMEPAD_BUTTON_NORTH:          return face_name(pad, button);
    case SDL_GAMEPAD_BUTTON_BACK:           return "select";
    case SDL_GAMEPAD_BUTTON_GUIDE:          return "home";
    case SDL_GAMEPAD_BUTTON_START:          return "start";
    case SDL_GAMEPAD_BUTTON_LEFT_STICK:     return "l3";
    case SDL_GAMEPAD_BUTTON_RIGHT_STICK:    return "r3";
    case SDL_GAMEPAD_BUTTON_LEFT_SHOULDER:  return "l1";
    case SDL_GAMEPAD_BUTTON_RIGHT_SHOULDER: return "r1";
    case SDL_GAMEPAD_BUTTON_DPAD_UP:        return "up";
    case SDL_GAMEPAD_BUTTON_DPAD_DOWN:      return "down";
    case SDL_GAMEPAD_BUTTON_DPAD_LEFT:      return "left";
    case SDL_GAMEPAD_BUTTON_DPAD_RIGHT:     return "right";
    default:                                return NULL;
    }
}

/* Turn an analog value into a held/released button with hysteresis. */
static void threshold(bool *held, bool active, bool inactive, const char *name)
{
    if (!*held && active) {
        *held = true;
        emit("down", name);
    } else if (*held && inactive) {
        *held = false;
        emit("up", name);
    }
}

static void on_axis(Pad *p, SDL_GamepadAxis axis, Sint16 v)
{
    switch (axis) {
    case SDL_GAMEPAD_AXIS_LEFTX:
        threshold(&p->left,  v < -STICK_ON, v > -STICK_OFF, "left");
        threshold(&p->right, v >  STICK_ON, v <  STICK_OFF, "right");
        break;
    case SDL_GAMEPAD_AXIS_LEFTY:
        threshold(&p->up,   v < -STICK_ON, v > -STICK_OFF, "up");
        threshold(&p->down, v >  STICK_ON, v <  STICK_OFF, "down");
        break;
    case SDL_GAMEPAD_AXIS_LEFT_TRIGGER:
        threshold(&p->lt, v > TRIGGER_ON, v < TRIGGER_OFF, "lt");
        break;
    case SDL_GAMEPAD_AXIS_RIGHT_TRIGGER:
        threshold(&p->rt, v > TRIGGER_ON, v < TRIGGER_OFF, "rt");
        break;
    default:
        break;
    }
}

static void add_pad(SDL_JoystickID id)
{
    if (find_pad(id))
        return;
    for (int i = 0; i < MAX_PADS; i++) {
        if (pads[i].pad)
            continue;
        SDL_Gamepad *pad = SDL_OpenGamepad(id);
        if (!pad) {
            fprintf(stderr, "pocket-input: can't open gamepad: %s\n", SDL_GetError());
            return;
        }
        memset(&pads[i], 0, sizeof(pads[i]));
        pads[i].id = id;
        pads[i].pad = pad;
        const char *name = SDL_GetGamepadName(pad);
        emit("connected", name ? name : "Gamepad");
        return;
    }
}

static void remove_pad(SDL_JoystickID id)
{
    Pad *p = find_pad(id);
    if (!p)
        return;
    const char *name = SDL_GetGamepadName(p->pad);
    emit("disconnected", name ? name : "Gamepad");
    SDL_CloseGamepad(p->pad);
    memset(p, 0, sizeof(*p));
}

int main(int argc, char **argv)
{
    (void)argc;
    (void)argv;

    /* There is no window, so SDL must deliver input without focus. */
    SDL_SetHint(SDL_HINT_JOYSTICK_ALLOW_BACKGROUND_EVENTS, "1");

    if (!SDL_Init(SDL_INIT_GAMEPAD)) {
        fprintf(stderr, "pocket-input: SDL_Init failed: %s\n", SDL_GetError());
        return 1;
    }

    emit("ready", "");

    SDL_Event ev;
    while (SDL_WaitEvent(&ev)) {
        switch (ev.type) {
        case SDL_EVENT_QUIT:
            SDL_Quit();
            return 0;
        case SDL_EVENT_GAMEPAD_ADDED:
            add_pad(ev.gdevice.which);
            break;
        case SDL_EVENT_GAMEPAD_REMOVED:
            remove_pad(ev.gdevice.which);
            break;
        case SDL_EVENT_GAMEPAD_BUTTON_DOWN:
        case SDL_EVENT_GAMEPAD_BUTTON_UP: {
            Pad *p = find_pad(ev.gbutton.which);
            if (!p)
                break;
            const char *name = button_name(p->pad, (SDL_GamepadButton)ev.gbutton.button);
            if (name)
                emit(ev.gbutton.down ? "down" : "up", name);
            break;
        }
        case SDL_EVENT_GAMEPAD_AXIS_MOTION: {
            Pad *p = find_pad(ev.gaxis.which);
            if (p)
                on_axis(p, (SDL_GamepadAxis)ev.gaxis.axis, ev.gaxis.value);
            break;
        }
        default:
            break;
        }
    }

    fprintf(stderr, "pocket-input: event wait failed: %s\n", SDL_GetError());
    SDL_Quit();
    return 1;
}
