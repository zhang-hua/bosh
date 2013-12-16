package action

import (
	"github.com/stretchr/testify/assert"
	"testing"
	fakesys "bosh/system/fakes"
	boshsys "bosh/system"
	boshas "bosh/agent/applier/applyspec"
	"encoding/json"
)

func TestDrainShouldBeAsynchronous(t *testing.T) {
	_, _, action := buildDrain()
	assert.True(t, action.IsAsynchronous())
}

func TestRunWithShutdown(t *testing.T) {
	cmdRunner, fs, action := buildDrain()

	oldSpec := boshas.V1ApplySpec{}
	oldSpec.JobSpec.Template = "foo"
	fs.WriteToFile("/var/vcap/bosh/spec.json", marshalSpecForTests(oldSpec))

	newSpec := boshas.V1ApplySpec{}
	drainStatus, err := action.Run("shutdown", newSpec)
	assert.NoError(t, err)
	assert.Equal(t, 0, drainStatus)

	expectedCmd := boshsys.Command{
		Name: "/var/vcap/jobs/foo/bin/drain",
		Args: []string{"job_shutdown", "hash_unchanged"},
		Env: map[string]string{
			"PATH": "/usr/sbin:/usr/bin:/sbin:/bin",
			"BOSH_CURRENT_STATE": marshalSpecForTests(newSpec),
			"BOSH_APPLY_SPEC": marshalSpecForTests(oldSpec),
		},
	}

	assert.Equal(t, 1, len(cmdRunner.RunComplexCommands))
	assert.Equal(t, expectedCmd, cmdRunner.RunComplexCommands[0])
}

func TestRunErrsWhenReadingTheCurrentSpecFails(t *testing.T) {
	_, fs, action := buildDrain()

	spec := `{"job":{"template":"fo`
	fs.WriteToFile("/var/vcap/bosh/spec.json", spec)

	_, err := action.Run("shutdown", boshas.V1ApplySpec{})
	assert.Error(t, err)
}

func buildDrain() (cmdRunner *fakesys.FakeCmdRunner, fs *fakesys.FakeFileSystem, action drainAction) {
	cmdRunner = fakesys.NewFakeCmdRunner()
	fs = fakesys.NewFakeFileSystem()
	action = newDrain(cmdRunner, fs)
	return
}

func marshalSpecForTests(spec boshas.V1ApplySpec) (contents string) {
	bytes, _ := json.Marshal(spec)
	contents = string(bytes)
	return
}
