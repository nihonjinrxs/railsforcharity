require 'spec_helper'

describe TasksController do
  let(:project) { create(:project) }
  let(:mail) { double("mail", :deliver => true) } # test double

  def valid_attributes
    {
      name: Faker.name,
      description: 'To build open source web based applications which help in improving the society.',
      estimated_hours: 2,
      estimated_minutes: 40,
      category: Task::CATEGORIES[:programming],
      task_type: Task::TYPES[:feature],
      project_id: project.id
    }
  end

  describe "POST create" do
    login_user

    describe "with valid params" do
      before :each do
        request.env["HTTP_REFERER"] = '/'
      end

      it "creates a new Task" do
        expect {
          post :create, {:task => valid_attributes}
        }.to change(Task, :count).by(1)
      end

      it "assigns a newly created task as @task" do
        post :create, {:task => valid_attributes}

        assigns(:task).should be_a(Task)
        assigns(:task).should be_persisted
        assigns(:task).estimated_time.should_not be_nil
        assigns(:task).estimated_time.should == 160
      end

      context 'collaborators do not have email preferences for task created.' do
        it 'does not email the collaborators' do
          QC.should_not_receive(:enqueue)

          post :create, { :task => valid_attributes }
        end
      end

      context 'collaborators have email preferences for task created' do
        it 'emails the collaborators' do
          john = build(:user)
          project.preferences.create(user: john, new_task: "1")
          project.preferences.create(user: user, new_task: "1")
          #task = create(:task, :creator => user, :estimated_hours => 4, project: project)

          QC.should_receive(:enqueue)#.with("Emailer.send_task_email", john.id, "new_task", task.id)
          QC.should_receive(:enqueue)#.with("Emailer.send_task_email", user.id, "new_task", task.id)

          post :create, { :task => valid_attributes }
        end
      end
    end

    describe "with invalid params" do
      it "assigns a newly created but unsaved task as @task" do
        # Trigger the behavior that occurs when invalid params are submitted
        Task.any_instance.stub(:save).and_return(false)
        post :create, {:task => {}}
        assigns(:task).should be_a_new(Task)
      end

      it "re-renders the 'new' template" do
        # Trigger the behavior that occurs when invalid params are submitted
        Task.any_instance.stub(:save).and_return(false)
        post :create, {:task => {}}
        response.should render_template("new")
      end
    end
  end

  def update
    respond_to do |format|
      if @task.update_attributes(params[:task])
        format.html { redirect_to @task, notice: t('controllers.tasks.update.success') }
        format.json { head :no_content }
      else
        format.html { render action: "edit" }
        format.json { render json: @project.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /projects/1
  # DELETE /projects/1.json
  def destroy
    @task.destroy

    respond_to do |format|
      format.html { redirect_to projects_url }
      format.json { head :no_content }
    end
  end

  describe "assign_me" do
    login_user

    before :each do
      @request.env['HTTP_REFERER'] = project_path(project)
    end

    it "assigns the task to the current user" do
      task = create(:task, :creator => user, :estimated_hours => 4, project: project)

      put :assign_me, {:id => task.to_param}

      task.reload
      task.assigned_to.should_not be_nil
      task.assigned_to.should == user.id
      task.estimated_hours.should == 4
    end

    context 'creator is assignee' do
      it 'does not email the creator' do
        task = create(:task, :creator => user, :estimated_hours => 4, project: project)
        QC.should_not_receive(:enqueue)
        put :assign_me, { :id => task.to_param }
      end
    end

    context 'creator is not assignee' do
      context 'creator has email preference for task_assigned' do
        it 'emails the creator' do
          john = create(:user)
          task = create(:task, :creator => john, :estimated_hours => 4, project: project)
          project.preferences.create(user: john, task_assigned: "1")

          QC.should_receive(:enqueue).with("Emailer.send_task_email", task.creator.id, "task_assigned", task.id)

          put :assign_me, {:id => task.to_param}
        end
      end

      context 'creator does not have email preference for task_assigned' do
        it 'does not email the creator' do
          john = build(:user)
          task = create(:task, :creator => john, :estimated_hours => 4, project: project)
          project.preferences.create(user: john)

          QC.should_not_receive(:enqueue)

          put :assign_me, {:id => task.to_param}
        end
      end
    end
  end

  describe "unassigned" do
    login_user

    before :each do
      @request.env['HTTP_REFERER'] = project_path(project)
    end

    it "unassigns the task to the current user" do
      task = create(:task, :creator => user, :estimated_hours => 4, project: project)

      put :unassigned, { :id => task.to_param }

      task.reload
      task.assigned_to.should be_nil
    end

    context 'creator is current user' do
      it 'does not email the creator' do
        task = create(:task, :creator => user, :estimated_hours => 4, project: project)
        QC.should_not_receive(:enqueue)
        put :unassigned, {:id => task.to_param}
      end
    end

    context 'creator is not the current user' do
      context 'creator has email preference for unassigned' do
        it 'emails the creator' do
          john = build(:user)
          task = create(:task, :creator => john, :estimated_hours => 4, project: project)
          project.preferences.create(user: john, task_unassigned: "1")

          QC.should_receive(:enqueue).with("Emailer.send_task_email", task.creator.id, "task_unassigned", task.id)

          put :unassigned, {:id => task.to_param}
        end
      end

      context 'creator does not have email preference for task_unassigned' do
        it 'does not email the creator' do
          john = build(:user)
          task = create(:task, :creator => john, :estimated_hours => 4, project: project)
          project.preferences.create(user: john)

          QC.should_not_receive(:enqueue)

          put :unassigned, {:id => task.to_param}
        end
      end
    end
  end

  describe "deliver" do
    login_user

    before :each do
      @request.env['HTTP_REFERER'] = project_path(project)
    end

    it "delivers the task to the current user" do
      task = create(:task, :creator => user, :estimated_hours => 4, project: project)

      put :deliver, {:id => task.to_param}

      task.reload
      task.assigned_to.should be_nil
    end

    context 'task delivered by the task creator' do
      it 'does not email the creator' do
        task = create(:task, :creator => user, :estimated_hours => 4, project: project)
        QC.should_not_receive(:enqueue)
        put :deliver, {:id => task.to_param}
      end
    end

    context 'task is not delivered by the task creator' do
      context 'creator has email preference for task_delivered' do
        it 'emails the creator' do
          john = build(:user)
          task = create(:task, :creator => john, :estimated_hours => 4, project: project)
          project.preferences.create(user: john, task_delivered: "1")

          QC.should_receive(:enqueue).with("Emailer.send_task_email", task.creator.id, "task_delivered", task.id)

          put :deliver, { :id => task.to_param }
        end
      end

      context 'creator does not have email preference for task_delivered' do
        it 'does not email the creator' do
          john = build(:user)
          task = create(:task, :creator => john, :estimated_hours => 4, project: project)
          project.preferences.create(user: john)

          QC.should_not_receive(:enqueue)

          put :deliver, { :id => task.to_param }
        end
      end
    end
  end

  describe "accept" do
    login_user

    before :each do
      @request.env['HTTP_REFERER'] = project_path(project)
    end

    it "accepts the task" do
      task = create(:task, :assigned_to => user, :estimated_hours => 4, project: project)

      put :accept, {:id => task.to_param}

      task.reload
      task.assigned_to.should_not be_nil
    end

    context 'Task assignee and task creator are same' do
      it 'does not email the assignee' do
        task = create(:task, :assignee => user, :estimated_hours => 4, project: project)
        QC.should_not_receive(:enqueue)
        put :accept, { :id => task.to_param }
      end
    end

    context 'task creator and assignee are different' do
      context 'assignee has email preference for task_accepted' do
        it 'emails the assignee' do
          john = build(:user)
          task = create(:task, :assignee => john, :created_by => user, :estimated_hours => 4, project: project)
          project.preferences.create(user: john, task_accepted: "1")

          QC.should_receive(:enqueue).with("Emailer.send_task_email", task.assignee.id, "task_accepted", task.id)

          put :accept, { :id => task.to_param }
        end
      end

      context 'assignee does not has email preference for task_accepted' do
        it 'does not email the assignee' do
          john = build(:user)
          task = create(:task, :assignee => john, :estimated_hours => 4, project: project)
          project.preferences.create(user: john)

          QC.should_not_receive(:enqueue)

          put :accept, {:id => task.to_param}

        end
      end
    end
  end

  describe "reject" do
    login_user

    before :each do
      @request.env['HTTP_REFERER'] = project_path(project)
    end

    it "rejects the task" do
      task = create(:task, :assigned_to => user, :estimated_hours => 4, project: project)

      put :reject, {:id => task.to_param}

      task.reload
      task.assigned_to.should_not be_nil
    end

    context 'Task assignee and task creator are same' do

      it 'does not email the assignee' do
        task = create(:task, :assignee => user, :estimated_hours => 4, project: project)
        QC.should_not_receive(:enqueue)
        put :reject, { :id => task.to_param }
      end
    end

    context 'task creator and assignee are different' do
      context 'assignee has email preference for task_rejected' do
        it 'emails the assignee' do
          john = build(:user)
          task = create(:task, :assignee => john, :created_by => user, :estimated_hours => 4, project: project)
          project.preferences.create(user: john, task_rejected: "1")

          QC.should_receive(:enqueue).with("Emailer.send_task_email", task.assignee.id, "task_rejected", task.id)

          put :reject, { :id => task.to_param }
        end
      end

      context 'assignee does not has email preference for task_rejected' do
        it 'does not email the assignee' do
          john = build(:user)
          task = create(:task, :assignee => john, :estimated_hours => 4, project: project)
          project.preferences.create(user: john)

          QC.should_not_receive(:enqueue)

          put :reject, {:id => task.to_param}
        end
      end
    end
  end
end
