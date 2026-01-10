#!/usr/bin/env bash
#
# session.sh - Session identity and management
#
# Provides functions for generating session identities with friendly,
# memorable animal names for distinguishing concurrent curb instances.
#
# Functions:
#   session_random_name() - Returns a random animal name
#

# Array of ~100 animal names (lowercase, single words)
ANIMAL_NAMES="aardvark albatross alpaca alligator anaconda ant anteater antelope ape armadillo badger bat bear beaver bee bison boar bobcat buffalo butterfly camel caribou cat caterpillar cheetah chimpanzee chinchilla chipmunk cobra cockroach cougar coyote crab crane crocodile crow cucumber cuckoo deer dingo dinosaur dog dolphin donkey dove dragonfly duck duffalo eagle eel eland elephant elk emu falcon ferret finch fish flamingo fly fox frog giraffe gnu goat goldfish goose gorilla grasshopper grouse guinea hare hawk hedgehog heron hippopotamus hornet horse hound hyena ibis icebear iguana impala insect jackal jaguar jay jellyfish jobfish kangaroo koala krill ladybug leopard lion llama locust loon lynx macaw magpie manatee mandrill meerkat mink minnow mole mongoose monkey moose mosquito moth mouse mule narwhal newt nightingale ocelot octopus otter owl ox panda panther parrot peccary pelican penguin pheasant pig pigeon pika pike poodle porcupine prairie puffin quail quokka rabbit raccoon raven reindeer rhinoceros rooster salmon saltpans sandpiper sardine seahorse seal sealion seaotter shark shearwater sheep shellduck shrew shrimp skunk sloth snail snake snipe snowgoose squirrel starfish stingray stork sturgeon swallow swan swift tapir tern tiger toad toucan turkey turtle uakari unau urchin urus viper vole vulture wallaby walrus wasp weasel weaver whale wolf wolverine wombat woodcock woodpecker wren"

# Pick a random animal name from the animal names
# Returns: a random animal name
session_random_name() {
    local animals
    local count
    local index

    # Convert the space-separated string into an array-like structure for selection
    animals=($ANIMAL_NAMES)
    count=${#animals[@]}

    # Use $RANDOM to get a random index
    index=$((RANDOM % count))

    echo "${animals[$index]}"
}
